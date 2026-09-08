import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/chat_label.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';

part 'chat_list_state.dart';

/// Drives the Chats inbox. The filter chooses which endpoint(s) feed the list:
/// direct/group come from GET /chats, broadcasts from GET /broadcasts, and
/// "All" merges both, newest-first.
class ChatListCubit extends Cubit<ChatListState> {
  ChatListCubit(this._repository) : super(const ChatListState());

  final ChatRepository _repository;

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
        final broadcasts = await _repository.getBroadcasts();
        // Merge; if both failed, surface an error, otherwise show what we got.
        if (chats is Err && broadcasts is Err) {
          return _emitError(
              chats.failureOrNull?.message ?? 'Could not load chats');
        }
        final merged = <Conversation>[
          ...chats.valueOrNull ?? const [],
          ...broadcasts.valueOrNull ?? const [],
        ]..sort(_byRecent);
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
    final at = a.lastMessageAt, bt = b.lastMessageAt;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return bt.compareTo(at);
  }
}
