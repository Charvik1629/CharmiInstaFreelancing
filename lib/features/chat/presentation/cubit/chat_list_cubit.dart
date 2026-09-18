import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/realtime/socket_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/chat_label.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';

part 'chat_list_state.dart';

/// Drives the Chats inbox. The filter chooses which endpoint(s) feed the list:
/// direct/group come from GET /chats, broadcasts from GET /broadcasts, and
/// "All" merges both, newest-first.
class ChatListCubit extends Cubit<ChatListState> {
  ChatListCubit(this._repository) : super(const ChatListState()) {
    _listenRealtime();
  }

  final ChatRepository _repository;

  final List<StreamSubscription<void>> _socketSubs = [];

  /// Keeps the inbox live: a new conversation (someone requested your post) or a
  /// new incoming message re-fetches the list so it appears / reorders at once.
  void _listenRealtime() {
    if (!sl.isRegistered<SocketService>()) return;
    final socket = sl<SocketService>();
    _socketSubs.add(socket.conversationCreated.listen((_) => _refreshLive()));
    _socketSubs.add(socket.messages.listen((_) => _refreshLive()));
  }

  /// A background refresh that doesn't flip the list into a loading spinner.
  void _refreshLive() {
    if (state.status == ChatListStatus.loading) return;
    _fetch();
  }

  @override
  Future<void> close() {
    for (final s in _socketSubs) {
      s.cancel();
    }
    return super.close();
  }

  /// The last fetched (unfiltered-by-label) list, so the label filter can be
  /// applied client-side without a refetch.
  List<Conversation> _raw = const [];

  Future<void> load() async {
    emit(state.copyWith(status: ChatListStatus.loading));
    await _loadLabels();
    await _fetch();
  }

  Future<void> refresh() => _fetch();

  Future<void> _loadLabels() async {
    final result = await _repository.getLabels();
    if (result case Success(value: final labels)) {
      emit(state.copyWith(labels: labels));
    }
  }

  /// Filters the raw list to the selected label (client-side).
  void setLabelFilter(int? labelId) {
    emit(labelId == null
        ? state.copyWith(clearLabelFilter: true)
        : state.copyWith(labelFilterId: labelId));
    _emitList(_raw);
  }

  /// Attaches or detaches [label] on [conversation], then reloads the list.
  Future<bool> toggleLabel(Conversation conversation, ChatLabel label) async {
    final has = conversation.labels.any((l) => l.id == label.id);
    final result = has
        ? await _repository.detachLabel(conversation.id, label.id)
        : await _repository.attachLabel(conversation.id, label.id);
    if (result.isSuccess) {
      await _fetch();
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }

  Future<void> setFilter(ChatFilter filter) async {
    if (filter == state.filter) return;
    emit(state.copyWith(filter: filter, status: ChatListStatus.loading, conversations: const []));
    await _fetch();
  }

  Future<void> _fetch() async {
    switch (state.filter) {
      case ChatFilter.all:
        final chats = await _repository.getChats();
        final questions = await _repository.getQuestions();
        final broadcasts = await _repository.getBroadcasts();
        // Merge all inbox sources; error only if everything failed.
        if (chats is Err && questions is Err && broadcasts is Err) {
          return _emitError(
              chats.failureOrNull?.message ?? 'Could not load chats');
        }
        final seen = <int>{};
        final merged = <Conversation>[
          ...chats.valueOrNull ?? const [],
          ...questions.valueOrNull ?? const [],
          ...broadcasts.valueOrNull ?? const [],
        ].where((c) => seen.add(c.id)).toList()
          ..sort(_byRecent);
        _emitList(merged);
      case ChatFilter.unread:
        _handle(await _repository.getChats(), keep: (c) => c.hasUnread);
      case ChatFilter.direct:
        _handle(await _repository.getChats(),
            keep: (c) => c.type == ConversationType.direct);
      case ChatFilter.groups:
        _handle(await _repository.getChats(),
            keep: (c) => c.type == ConversationType.group);
      case ChatFilter.questions:
        _handle(await _repository.getQuestions());
      case ChatFilter.photos:
        _handle(await _repository.getChats(hasMedia: 'image'));
      case ChatFilter.videos:
        _handle(await _repository.getChats(hasMedia: 'video'));
      case ChatFilter.voice:
        _handle(await _repository.getChats(hasMedia: 'audio'));
      case ChatFilter.links:
        _handle(await _repository.getChats(hasLinks: true));
      case ChatFilter.broadcasts:
        _handle(await _repository.getBroadcasts());
    }
  }

  void _handle(Result<List<Conversation>> result, {bool Function(Conversation)? keep}) {
    switch (result) {
      case Success(value: final list):
        final filtered = (keep == null ? list : list.where(keep).toList())
          ..sort(_byRecent);
        _emitList(filtered);
      case Err(failure: final f):
        _emitError(f.message);
    }
  }

  void _emitList(List<Conversation> list) {
    _raw = list;
    final labelId = state.labelFilterId;
    final shown = labelId == null
        ? list
        : list.where((c) => c.labels.any((l) => l.id == labelId)).toList();
    emit(state.copyWith(
      status: shown.isEmpty ? ChatListStatus.empty : ChatListStatus.loaded,
      conversations: shown,
      clearError: true,
    ));
  }

  void _emitError(String message) {
    emit(state.copyWith(status: ChatListStatus.error, errorMessage: message));
  }

  /// Newest activity first; threads without a last message sink to the bottom.
  static int _byRecent(Conversation a, Conversation b) {
    // Pinned conversations always sort above unpinned ones.
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    final at = a.lastMessageAt, bt = b.lastMessageAt;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return bt.compareTo(at);
  }

  /// Pins / unpins a conversation, then reloads so it re-sorts to the top.
  Future<Result<void>> togglePin(Conversation c) async {
    final result =
        await _repository.pinConversation(c.id, pin: !c.isPinned);
    if (result.isSuccess) await _fetch();
    return result;
  }
}
