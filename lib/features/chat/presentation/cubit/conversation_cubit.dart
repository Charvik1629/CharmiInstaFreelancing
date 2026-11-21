import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/realtime/socket_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/broadcast_quota.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/disappearing_settings.dart';
import '../../domain/entities/message_reaction.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import 'unread_cubit.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

part 'conversation_state.dart';

/// Drives a single thread (direct, group or broadcast). Loads the most recent
/// window of messages, pages older ones on demand, and sends new ones.
class ConversationCubit extends Cubit<ConversationState> {
  ConversationCubit(this._repository, this.conversation, {this.meId})
    : super(ConversationState(disappearing: conversation.disappearing)) {
    _listenRealtime();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!sl.isRegistered<SocketService>() ||
          !sl<SocketService>().isConnected) {
        _catchUp();
      }
    });
    _expiryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => expireDueMessages(),
    );
  }

  final ChatRepository _repository;
  final Conversation conversation;
  final int? meId;

  StreamSubscription<RealtimeMessage>? _socketSub;
  StreamSubscription<TypingEvent>? _typingSub;
  StreamSubscription<ReadEvent>? _readSub;
  StreamSubscription<PresenceEvent>? _presenceSub;
  StreamSubscription<void>? _connectedSub;
  Timer? _typingClear;
  Timer? _presenceTimer;
  Timer? _expiryTimer;
  Timer? _syncTimer;
  bool _catchingUp = false;
  StreamSubscription<ChatChangeEvent>? _changesSub;

  bool get canSend =>
      conversation.canChat &&
      (!sl.isRegistered<AuthCubit>() ||
          sl<AuthCubit>().state.user?.canChat == true);

  /// True when this is a broadcast whose free allowance is spent and the next
  /// message will be charged — the page must confirm the credit debit first.
  bool get broadcastOverLimit =>
      conversation.type == ConversationType.broadcast &&
      (state.broadcastQuota?.overFreeLimit ?? false);

  /// Credits the next broadcast message will cost (0 if unknown / free).
  int get broadcastNextCost => state.broadcastQuota?.nextCreditCost ?? 0;

  /// The free-message allowance for this broadcast list (0 if unknown).
  int get broadcastFreeLimit => state.broadcastQuota?.freeLimit ?? 0;

  /// Clears the transient quota-403 signal once the page has shown the dialog.
  void clearBroadcastLimit() {
    if (state.broadcastLimitReached) {
      emit(state.copyWith(broadcastLimitReached: false));
    }
  }

  /// Re-reads `meta.broadcast_message_quota` (broadcast threads only).
  Future<void> _refreshBroadcastQuota() async {
    if (conversation.type != ConversationType.broadcast) return;
    final res = await _repository.getBroadcastQuota(conversation.id);
    if (res case Success(value: final q) when q != null && !isClosed) {
      emit(state.copyWith(broadcastQuota: q));
    }
  }

  /// Subscribes to live `message:new` events for this thread (falls back to the
  /// existing polling when the socket isn't connected).
  void _listenRealtime() {
    if (!sl.isRegistered<SocketService>()) return;
    final socket = sl<SocketService>();
    socket.joinConversation(conversation.id);
    _changesSub = socket.chatChanges
        .where((e) => e.conversationId == conversation.id)
        .listen(applyChatChange);
    // On (re)connect after a background drop, re-join the room and refetch the
    // latest messages — events missed while disconnected aren't replayed, so
    // this catches up new messages without a manual pull-to-refresh.
    _connectedSub = socket.connected.listen((_) {
      socket.joinConversation(conversation.id);
      _catchUp();
    });
    _socketSub = socket.messages
        .where((m) => m.conversationId == conversation.id)
        .listen((m) {
          // A live message can be the echo of one we just sent. Skip it if it's
          // already here by server id, or if it's an un-idized echo of the tail.
          if (_isLiveDuplicate(m.message)) return;
          emit(
            state.copyWith(
              messages: [...state.messages, m.message],
              status: ThreadStatus.loaded,
              clearTyping: true,
            ),
          );
          _markRead();
        });
    // Peer "typing…" — auto-clears if no follow-up event arrives.
    _typingSub = socket.typingEvents
        .where((t) => t.conversationId == conversation.id)
        .listen((t) {
          _typingClear?.cancel();
          if (t.isTyping) {
            emit(state.copyWith(typingName: t.name ?? 'typing'));
            _typingClear = Timer(
              const Duration(seconds: 5),
              () => emit(state.copyWith(clearTyping: true)),
            );
          } else {
            emit(state.copyWith(clearTyping: true));
          }
        });
    // Peer read marker → drives the read tick on my messages.
    _readSub = socket.readEvents
        .where((r) => r.conversationId == conversation.id && r.userId != meId)
        .listen((r) {
          final prev = state.peerLastReadAt;
          if (prev == null || r.lastReadAt.isAfter(prev)) {
            emit(state.copyWith(peerLastReadAt: r.lastReadAt));
          }
        });
    // Peer online / last-seen (direct chats). The backend does NOT push
    // presence changes (server_events has no presence:update), so we POLL with
    // `presence:check` on open and every 20s while the thread is open — matching
    // the server's 25s ping / 60s timeout model.
    final peerId = conversation.peerId;
    if (peerId != null && conversation.type == ConversationType.direct) {
      _pollPresence(peerId);
      // The backend doesn't push `message:read`, so besides presence we also
      // re-read the peer's read cursor here — that's what turns my ✓ into ✓✓
      // once the peer opens the thread (without me having to reload).
      _presenceTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _pollPresence(peerId);
        _seedPeerRead();
      });
      // Also honour a push presence:update if the backend ever adds one.
      _presenceSub = socket.presenceEvents
          .where((p) => p.userId == peerId)
          .listen(
            (p) => emit(
              state.copyWith(
                peerOnline: p.isOnline,
                peerLastSeen: p.lastSeenAt,
              ),
            ),
          );
    }
  }

  /// Refetches the latest message window and appends any messages not already
  /// in the thread (used after a reconnect to catch up ones missed while the
  /// socket was down). Doesn't show a spinner or disturb older-page scroll.
  Future<void> _catchUp() async {
    if (state.status == ThreadStatus.loading || isClosed || _catchingUp) return;
    _catchingUp = true;
    final result = await _repository.getMessages(
      id: conversation.id,
      type: conversation.type,
    );
    _catchingUp = false;
    if (result case Success(value: final page) when !isClosed) {
      final fetched = {for (final m in page.items) m.id: m};
      final oldest = page.items.isEmpty ? null : page.items.first.id;
      final messages = !page.hasMore
          ? page.items
          : [
              for (final m in state.messages)
                if (fetched.containsKey(m.id))
                  fetched.remove(m.id)!
                else if (oldest != null && m.id < oldest)
                  m,
              ...fetched.values,
            ];
      messages.sort((a, b) => a.id.compareTo(b.id));
      emit(
        state.copyWith(
          messages: messages,
          status: messages.isEmpty ? ThreadStatus.empty : ThreadStatus.loaded,
        ),
      );
      expireDueMessages();
      _markRead();
      loadDetails();
    }
  }

  void _pollPresence(int peerId) {
    if (!sl.isRegistered<SocketService>()) return;
    sl<SocketService>().checkPresence([peerId]).then((map) {
      final info = map[peerId];
      if (info != null && !isClosed) {
        emit(
          state.copyWith(
            peerOnline: info.isOnline,
            peerLastSeen: info.lastSeenAt,
          ),
        );
      }
    });
  }

  Timer? _typingEmitStop;
  bool _typingSent = false;

  /// Call on each keystroke: emits `typing:start` once, then `typing:stop` after
  /// a short idle gap (debounced so we don't flood the socket).
  void notifyTyping() {
    if (!sl.isRegistered<SocketService>()) return;
    final socket = sl<SocketService>();
    if (!_typingSent) {
      socket.typing(conversation.id, started: true);
      _typingSent = true;
    }
    _typingEmitStop?.cancel();
    _typingEmitStop = Timer(const Duration(seconds: 2), () {
      socket.typing(conversation.id, started: false);
      _typingSent = false;
    });
  }

  void _stopTyping() {
    _typingEmitStop?.cancel();
    if (_typingSent && sl.isRegistered<SocketService>()) {
      sl<SocketService>().typing(conversation.id, started: false);
    }
    _typingSent = false;
  }

  bool _sameContent(ChatMessage a, ChatMessage b) =>
      a.senderId == b.senderId &&
      (a.body ?? '') == (b.body ?? '') &&
      a.imageUrl == b.imageUrl;

  /// Whether an incoming *socket* message is already in the thread: by server id
  /// when it has one, otherwise an echo of our own just-sent tail message (the
  /// authoritative copy from the send response stays).
  bool _isLiveDuplicate(ChatMessage incoming) {
    if (incoming.id > 0) {
      return state.messages.any((x) => x.id == incoming.id);
    }
    final msgs = state.messages;
    return msgs.isNotEmpty && _sameContent(msgs.last, incoming);
  }

  /// Appends the authoritative message from a send response — but if the live
  /// socket already delivered the same one (matched by server id, or as an
  /// un-idized echo), replaces that copy instead of adding a duplicate. Fixes the
  /// race where the socket echo arrives before the POST response returns.
  List<ChatMessage> _reconcile(ChatMessage message) {
    final msgs = [...state.messages];
    final at = msgs.indexWhere(
      (x) =>
          (message.id > 0 && x.id == message.id) ||
          (x.id <= 0 && _sameContent(x, message)),
    );
    if (at >= 0) {
      msgs[at] = message;
    } else {
      msgs.add(message);
    }
    return msgs;
  }

  @override
  Future<void> close() {
    _syncTimer?.cancel();
    _expiryTimer?.cancel();
    _changesSub?.cancel();
    _socketSub?.cancel();
    _connectedSub?.cancel();
    _typingSub?.cancel();
    _readSub?.cancel();
    _presenceSub?.cancel();
    _presenceTimer?.cancel();
    _typingClear?.cancel();
    _typingEmitStop?.cancel();
    return super.close();
  }

  Future<void> load() async {
    emit(state.copyWith(status: ThreadStatus.loading));
    final result = await _repository.getMessages(
      id: conversation.id,
      type: conversation.type,
    );
    if (isClosed) return;
    switch (result) {
      case Success(value: final page):
        emit(
          state.copyWith(
            status: page.items.isEmpty
                ? ThreadStatus.empty
                : ThreadStatus.loaded,
            messages: page.items,
            hasMore: page.hasMore,
            nextBeforeId: page.nextBeforeId,
          ),
        );
        expireDueMessages();
        _markRead();
        _refreshBroadcastQuota();
        _seedPeerRead();
      case Err(failure: final f):
        emit(
          state.copyWith(status: ThreadStatus.error, errorMessage: f.message),
        );
    }
  }

  /// Seeds the peer's read cursor on load (1:1 only), so ✓✓ shows immediately
  /// without waiting for a live `message:read` socket event.
  Future<void> _seedPeerRead() async {
    if (conversation.type != ConversationType.direct || conversation.isSelf) {
      return;
    }
    final res = await _repository.getPeerLastRead(conversation.id);
    if (res case Success(value: final at) when at != null && !isClosed) {
      final prev = state.peerLastReadAt;
      if (prev == null || at.isAfter(prev)) {
        emit(state.copyWith(peerLastReadAt: at));
      }
    }
  }

  /// Loads an older page and prepends it (older messages sit above).
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.nextBeforeId == null) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    final result = await _repository.getMessages(
      id: conversation.id,
      type: conversation.type,
      beforeId: state.nextBeforeId,
    );
    if (isClosed) return;
    switch (result) {
      case Success(value: final page):
        final existing = state.messages.map((m) => m.id).toSet();
        emit(
          state.copyWith(
            messages: [
              ...page.items.where((m) => !existing.contains(m.id)),
              ...state.messages,
            ],
            hasMore: page.hasMore,
            nextBeforeId: page.nextBeforeId,
            isLoadingMore: false,
          ),
        );
      case Err():
        emit(state.copyWith(isLoadingMore: false, hasMore: false));
    }
  }

  /// Sends a text message.
  Future<void> send(String text) => _send(body: text.trim());

  /// Sends an image attachment (with optional caption).
  Future<void> sendImage(String imagePath, {String caption = ''}) =>
      _send(body: caption.trim(), attachmentPaths: [imagePath]);

  /// Sends any file attachment — video or document (with optional caption). The
  /// server infers the kind (image|video|audio|file) from the file's mime type.
  Future<void> sendAttachment(String path, {String caption = ''}) =>
      _send(body: caption.trim(), attachmentPaths: [path]);

  /// Sends multiple file attachments in one message (up to 5, per the API).
  Future<void> sendAttachments(List<String> paths, {String caption = ''}) =>
      _send(body: caption.trim(), attachmentPaths: paths.take(5).toList());

  /// Shared send path; on success appends the created message to the bottom.
  Future<void> _send({
    String body = '',
    List<String> attachmentPaths = const [],
  }) async {
    if ((body.isEmpty && attachmentPaths.isEmpty) ||
        state.isSending ||
        !canSend) {
      return;
    }
    _stopTyping();
    emit(state.copyWith(isSending: true, clearError: true));
    final replyingTo = state.replyingTo;
    final result = await _repository.sendMessage(
      id: conversation.id,
      type: conversation.type,
      body: body,
      attachmentPaths: attachmentPaths,
      replyToMessageId: conversation.isBroadcast ? null : replyingTo?.id,
    );
    if (isClosed) return;
    final isBroadcast = conversation.type == ConversationType.broadcast;
    switch (result) {
      case Success(value: final message):
        emit(
          state.copyWith(
            messages: _reconcile(message),
            status: ThreadStatus.loaded,
            isSending: false,
            broadcastLimitReached: false,
            clearReply: state.replyingTo?.id == replyingTo?.id,
          ),
        );
        // Refresh the quota so the next send knows the updated used-count/cost.
        if (isBroadcast) _refreshBroadcastQuota();
      case Err(failure: final f):
        // A 403 on a broadcast send is the "limit over · subscribe" case — flag
        // it so the page can raise the unfunded overage dialog.
        emit(
          state.copyWith(
            isSending: false,
            errorMessage: f.message,
            broadcastLimitReached: isBroadcast && f.statusCode == 403,
          ),
        );
    }
  }

  /// Sends a location message (lat/lng + label).
  Future<Result<ChatMessage>> sendLocation(
    double lat,
    double lng,
    String label,
  ) async {
    if (!canSend) return const Err(ForbiddenFailure());
    final replyingTo = state.replyingTo;
    final result = await _repository.sendMeta(
      conversationId: conversation.id,
      type: 'location',
      meta: {'lat': lat, 'lng': lng, 'label': label},
      replyToMessageId: replyingTo?.id,
    );
    if (result case Success(value: final m) when !isClosed) {
      emit(
        state.copyWith(
          messages: _reconcile(m),
          status: ThreadStatus.loaded,
          clearReply: state.replyingTo?.id == replyingTo?.id,
        ),
      );
    }
    return result;
  }

  /// Sends a one-to-one inquiry (question + optional INR price string).
  Future<Result<ChatMessage>> sendInquiry(String body, String? price) async {
    if (!canSend) return const Err(ForbiddenFailure());
    final replyingTo = state.replyingTo;
    final result = await _repository.sendInquiry(
      conversationId: conversation.id,
      body: body,
      price: price,
      replyToMessageId: replyingTo?.id,
    );
    if (result case Success(value: final m) when !isClosed) {
      emit(
        state.copyWith(
          messages: _reconcile(m),
          status: ThreadStatus.loaded,
          clearReply: state.replyingTo?.id == replyingTo?.id,
        ),
      );
    }
    return result;
  }

  /// Blocks the other user in a direct chat.
  Future<Result<void>> blockPeer() async {
    final id = conversation.peerId;
    if (id == null || conversation.isSelf) {
      return const Err(ValidationFailure('No other user to block'));
    }
    return _repository.blockUser(id);
  }

  /// Edits a text message in place.
  Future<Result<ChatMessage>> editMessage(int messageId, String body) async {
    final result = await _repository.editMessage(
      conversation.id,
      messageId,
      body,
    );
    if (result case Success(value: final updated)) {
      emit(
        state.copyWith(
          messages: [
            for (final m in state.messages)
              if (m.id == messageId) updated else m,
          ],
        ),
      );
    }
    return result;
  }

  /// Stars / unstars a message (optimistic; reverts on failure).
  Future<Result<void>> toggleStar(ChatMessage msg) async {
    final target = !msg.isStarred;
    emit(
      state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == msg.id) m.copyWith(isStarred: target) else m,
        ],
      ),
    );
    final result = await _repository.starMessage(
      conversation.id,
      msg.id,
      star: target,
    );
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          messages: [
            for (final m in state.messages)
              if (m.id == msg.id) m.copyWith(isStarred: !target) else m,
          ],
        ),
      );
    }
    return result;
  }

  void startReply(ChatMessage message) {
    if (canSend &&
        !conversation.isBroadcast &&
        message.canInteract &&
        !message.hasExpired()) {
      emit(state.copyWith(replyingTo: message));
    }
  }

  void cancelReply() => emit(state.copyWith(clearReply: true));

  Future<void> loadDetails() async {
    if (conversation.isBroadcast) return;
    final result = await _repository.getConversation(conversation.id);
    if (result case Success(value: final detail) when !isClosed) {
      emit(state.copyWith(disappearing: detail.disappearing));
    }
  }

  Future<Result<DisappearingUpdate>> setDisappearing({
    required bool enabled,
    int? hours,
  }) async {
    final result = await _repository.setDisappearing(
      conversation.id,
      enabled: enabled,
      hours: hours,
    );
    if (result case Success(value: final update) when !isClosed) {
      emit(
        state.copyWith(
          disappearing: update.settings,
          messages: update.message == null
              ? state.messages
              : _reconcile(update.message!),
          status: update.message == null ? state.status : ThreadStatus.loaded,
        ),
      );
    }
    return result;
  }

  Future<Result<ReactionUpdate>> react(
    ChatMessage message,
    String? emoji,
  ) async {
    if (state.changingMessages.contains(message.id)) {
      return const Err(ValidationFailure('Please wait.'));
    }
    emit(
      state.copyWith(changingMessages: {...state.changingMessages, message.id}),
    );
    final result = await _repository.react(conversation.id, message.id, emoji);
    if (result case Success(value: final update) when !isClosed) {
      _applyReactions(update);
    }
    if (!isClosed) {
      emit(
        state.copyWith(
          changingMessages: {...state.changingMessages}..remove(message.id),
        ),
      );
    }
    return result;
  }

  void _applyReactions(ReactionUpdate update) {
    emit(
      state.copyWith(
        messages: [
          for (final message in state.messages)
            if (message.id == update.messageId && !message.isDeleted)
              message.copyWith(
                reactions: update.reactions,
                myReaction: update.myReaction,
                clearReaction: update.myReaction == null,
              )
            else
              message,
        ],
      ),
    );
  }

  Future<Result<ChatMessage>> keepMessage(ChatMessage message) async {
    final result = await _repository.keepMessage(conversation.id, message.id);
    if (result case Success(value: final updated) when !isClosed) {
      _replaceMessage(updated);
    }
    return result;
  }

  void _replaceMessage(ChatMessage updated) {
    if (state.messages.any((m) => m.id == updated.id && m.isDeleted) &&
        !updated.isDeleted) {
      return;
    }
    emit(
      state.copyWith(
        messages: [
          for (final message in state.messages)
            if (message.id == updated.id)
              updated
            else if (message.replyToMessageId == updated.id &&
                updated.isDeleted)
              message.copyWith(replyTo: MessageReply.fromMessage(updated))
            else
              message,
        ],
        clearReply: state.replyingTo?.id == updated.id && updated.isDeleted,
      ),
    );
  }

  Future<Result<void>> deleteMessage(
    int messageId, {
    MessageDeleteScope scope = MessageDeleteScope.everyone,
  }) async {
    final result = await _repository.deleteMessage(
      conversation.id,
      messageId,
      scope: scope,
    );
    if (result.isSuccess && !isClosed) {
      if (scope == MessageDeleteScope.me) {
        _hideMessage(messageId);
      } else {
        final message = state.messages
            .where((m) => m.id == messageId)
            .firstOrNull;
        if (message != null) _replaceMessage(message.deleted());
      }
    }
    return result;
  }

  void _hideMessage(int id) {
    final messages = state.messages.where((m) => m.id != id).toList();
    emit(
      state.copyWith(
        messages: messages,
        status: messages.isEmpty ? ThreadStatus.empty : ThreadStatus.loaded,
        clearReply: state.replyingTo?.id == id,
      ),
    );
  }

  Future<Result<void>> deleteChat() async {
    final result = await _repository.deleteConversation(conversation.id);
    if (result.isSuccess && !isClosed) {
      emit(state.copyWith(chatDeleted: true, messages: [], clearReply: true));
    }
    return result;
  }

  void expireDueMessages() {
    if (isClosed) return;
    final due = state.messages
        .where((m) => !m.isDeleted && m.hasExpired())
        .toList();
    for (final message in due) {
      _replaceMessage(message.deleted());
    }
  }

  void applyChatChange(ChatChangeEvent event) {
    if (isClosed || event.conversationId != conversation.id) return;
    switch (event.kind) {
      case 'message:updated':
      case 'message:deleted':
        _replaceMessage(ChatMessage.fromJson(event.data));
      case 'message:hidden':
        _hideMessage(event.messageId ?? 0);
      case 'message:reaction':
        _applyReactions(ReactionUpdate.fromJson(event.data, meId: meId));
      case 'conversation:updated':
        final inner = event.data['conversation'];
        final data = inner is Map<String, dynamic> ? inner : event.data;
        if (data.containsKey('disappearing_messages')) {
          emit(
            state.copyWith(disappearing: DisappearingSettings.fromJson(data)),
          );
        } else {
          loadDetails();
        }
      case 'conversation:deleted':
        emit(state.copyWith(chatDeleted: true, messages: [], clearReply: true));
    }
  }

  void _markRead() {
    if (conversation.type == ConversationType.broadcast) return;
    _repository.markRead(conversation.id).then((_) async {
      // Refresh the global unread badge so the bottom-nav dot clears too.
      if (!sl.isRegistered<UnreadCubit>()) return;
      final counts = await _repository.getUnreadCounts();
      if (counts case Success(value: final c)) {
        sl<UnreadCubit>().setCounts(c);
      }
    });
  }
}
