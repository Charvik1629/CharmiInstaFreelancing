import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/user.dart';
import '../../../../core/realtime/socket_service.dart';
import '../../../../core/utils/result.dart';
import '../../../search/domain/repositories/search_repository.dart';
import '../../domain/entities/chat_label.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';

part 'chat_list_state.dart';

/// Drives the Chats inbox. The filter chooses which endpoint(s) feed the list:
/// direct/group come from GET /chats, broadcasts from GET /broadcasts, and
/// "All" merges both, newest-first. While searching, it also looks up people
/// (GET /users?q=) so you can start a new chat from the same bar.
class ChatListCubit extends Cubit<ChatListState> {
  ChatListCubit(this._repository, this._search) : super(const ChatListState()) {
    _listenRealtime();
  }

  final ChatRepository _repository;
  final SearchRepository _search;

  final List<StreamSubscription<void>> _socketSubs = [];

  /// Keeps the inbox live: a new conversation (someone requested your post) or a
  /// new incoming message re-fetches the list so it appears / reorders at once.
  void _listenRealtime() {
    if (!sl.isRegistered<SocketService>()) return;
    final socket = sl<SocketService>();
    _socketSubs.add(socket.conversationCreated.listen((_) => _refreshLive()));
    _socketSubs.add(socket.messages.listen((_) => _refreshLive()));
    // A live `unread:update` (new message, or a thread I just read elsewhere)
    // changes a row's badge / order — refresh so the inbox reflects it at once.
    _socketSubs.add(socket.unreadUpdates.listen((_) => _refreshLive()));
    // On (re)connect — e.g. returning from background — events missed while the
    // socket was down aren't replayed, so refetch to catch up new conversations
    // and messages without a manual pull-to-refresh.
    _socketSubs.add(socket.connected.listen((_) => _refreshLive()));
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
    _searchDebounce?.cancel();
    return super.close();
  }

  Future<void> load() async {
    emit(state.copyWith(status: ChatListStatus.loading));
    await _loadLabels();
    await _fetch();
  }

  Future<void> refresh() => _fetch();

  Future<void> _loadLabels() async {
    final result = await _repository.getLabels();
    if (isClosed) return; // navigated away mid-load (e.g. an auth bounce)
    if (result case Success(value: final labels)) {
      emit(state.copyWith(labels: labels));
    }
  }

  /// Live text search (GET /chats?q= — matches peer/group/load title and
  /// message bodies). Debounced so typing doesn't flood the API.
  String _query = '';
  Timer? _searchDebounce;

  /// The server `q` param: the trimmed query, or null when empty so we don't
  /// send a pointless `?q=` (and so "load all" stays a plain GET /chats).
  String? get _q => _query.isEmpty ? null : _query;

  void setSearch(String q) {
    _query = q.trim();
    _searchDebounce?.cancel();
    emit(state.copyWith(query: q));
    if (_query.isEmpty) {
      // Cleared → drop people results and reload the plain inbox.
      emit(state.copyWith(people: const []));
      _fetch();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetch();
      _searchPeople();
    });
  }

  /// Resets the inbox search back to the plain chat list (used when returning
  /// from a chat opened out of a search result).
  void clearSearch() {
    if (_query.isEmpty && state.people.isEmpty && state.query.isEmpty) return;
    _query = '';
    _searchDebounce?.cancel();
    emit(state.copyWith(query: '', people: const []));
    _fetch();
  }

  /// Looks up app users for the search term so a new chat can be started from
  /// the inbox search (GET /users?q=).
  Future<void> _searchPeople() async {
    final q = _query;
    if (q.isEmpty) return;
    final result = await _search.searchUsers(q);
    if (isClosed || q != _query) return; // superseded by a newer keystroke
    if (result case Success(value: final users)) {
      emit(state.copyWith(people: users));
    }
  }

  /// Keeps questions/broadcasts (which have no server `q`) in sync with the
  /// text search by matching title/subtitle/last message client-side.
  bool _matchesQuery(Conversation c) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return c.title.toLowerCase().contains(q) ||
        (c.subtitle ?? '').toLowerCase().contains(q) ||
        (c.lastMessage ?? '').toLowerCase().contains(q);
  }

  /// Starts (or opens) a direct chat with a user picked from people search.
  Future<Result<Conversation>> startChat(int userId) =>
      _repository.startChat(userId);

  /// Re-fetches the user's labels (e.g. after creating one on the Manage
  /// Labels screen, so the filter row + attach sheet show it immediately).
  Future<void> reloadLabels() => _loadLabels();

  /// Filters the inbox to the selected label. Tapping the active label again
  /// clears it. A label spans every chat, so this switches to the "all" source
  /// and re-fetches, then narrows client-side in [_emitList].
  Future<void> setLabelFilter(int? labelId) async {
    // Toggle the active label off → back to the plain "All" view.
    if (labelId == null || labelId == state.labelFilterId) {
      emit(state.copyWith(
          clearLabelFilter: true, filter: ChatFilter.all, status: ChatListStatus.loading));
      await _fetch();
      return;
    }
    emit(state.copyWith(
        labelFilterId: labelId,
        filter: ChatFilter.all,
        status: ChatListStatus.loading,
        conversations: const []));
    await _fetch();
  }

  /// Attaches or detaches [label] on [conversation], then reloads the list.
  /// The attached-state is read from the latest list (not the passed snapshot)
  /// so repeated toggles in the same sheet stay correct.
  Future<bool> toggleLabel(Conversation conversation, ChatLabel label) async {
    final current = state.conversations.firstWhere(
      (c) => c.id == conversation.id && c.type == conversation.type,
      orElse: () => conversation,
    );
    final has = current.labels.any((l) => l.id == label.id);
    final result = has
        ? await _repository.detachLabel(current.id, label.id)
        : await _repository.attachLabel(current.id, label.id);
    if (isClosed) return false;
    if (result.isSuccess) {
      await _fetch();
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }

  /// Detaches every label from [conversation] (the "Remove label" action, which
  /// clears without a picker). Returns false if any detach failed.
  Future<bool> clearLabels(Conversation conversation) async {
    final current = state.conversations.firstWhere(
      (c) => c.id == conversation.id && c.type == conversation.type,
      orElse: () => conversation,
    );
    var ok = true;
    for (final l in current.labels) {
      final r = await _repository.detachLabel(current.id, l.id);
      if (!r.isSuccess) {
        ok = false;
        if (!isClosed) {
          emit(state.copyWith(errorMessage: r.failureOrNull?.message));
        }
      }
    }
    if (isClosed) return ok;
    await _fetch();
    return ok;
  }

  Future<void> setFilter(ChatFilter filter) async {
    if (filter == state.filter && state.labelFilterId == null) return;
    // Picking a built-in filter clears any active label filter.
    emit(state.copyWith(
        filter: filter,
        clearLabelFilter: true,
        status: ChatListStatus.loading,
        conversations: const []));
    await _fetch();
  }

  Future<void> _fetch() async {
    switch (state.filter) {
      case ChatFilter.all:
        final chats = await _repository.getChats(q: _q);
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
        ].where((c) => _matchesQuery(c) && seen.add(c.id)).toList()
          ..sort(_byRecent);
        _emitList(merged);
      case ChatFilter.unread:
        _handle(await _repository.getChats(q: _q),
            keep: (c) => c.hasUnread);
      case ChatFilter.direct:
        _handle(await _repository.getChats(q: _q),
            keep: (c) => c.type == ConversationType.direct);
      case ChatFilter.groups:
        _handle(await _repository.getChats(q: _q),
            keep: (c) => c.type == ConversationType.group);
      case ChatFilter.questions:
        _handle(await _repository.getQuestions(), keep: _matchesQuery);
      case ChatFilter.photos:
        _handle(await _repository.getChats(hasMedia: 'image', q: _q));
      case ChatFilter.videos:
        _handle(await _repository.getChats(hasMedia: 'video', q: _q));
      case ChatFilter.voice:
        _handle(await _repository.getChats(hasMedia: 'audio', q: _q));
      case ChatFilter.links:
        _handle(await _repository.getChats(hasLinks: true, q: _q));
      case ChatFilter.broadcasts:
        _handle(await _repository.getBroadcasts(), keep: _matchesQuery);
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
    if (isClosed) return; // navigated away mid-fetch (e.g. an auth bounce)
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
    if (isClosed) return; // navigated away mid-fetch (e.g. an auth bounce)
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
