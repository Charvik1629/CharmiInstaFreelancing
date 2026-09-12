import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/realtime/socket_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';

part 'conversation_state.dart';

/// Drives a single thread (direct, group or broadcast). Loads the most recent
/// window of messages, pages older ones on demand, and sends new ones.
class ConversationCubit extends Cubit<ConversationState> {
  ConversationCubit(this._repository, this.conversation, {this.meId})
      : super(const ConversationState()) {
    _listenRealtime();
  }

  final ChatRepository _repository;
  final Conversation conversation;
  final int? meId;

  StreamSubscription<RealtimeMessage>? _socketSub;

  bool get canSend => conversation.canChat;

  /// Subscribes to live `message:new` events for this thread (falls back to the
  /// existing polling when the socket isn't connected).
  void _listenRealtime() {
    if (!sl.isRegistered<SocketService>()) return;
    final socket = sl<SocketService>();
    socket.joinConversation(conversation.id);
    _socketSub = socket.messages
        .where((m) => m.conversationId == conversation.id)
        .listen((m) {
      // Skip messages we already have (e.g. our own, appended on send).
      if (state.messages.any((x) => x.id == m.message.id)) return;
      emit(state.copyWith(
        messages: [...state.messages, m.message],
        status: ThreadStatus.loaded,
      ));
      _markRead();
    });
  }

  @override
  Future<void> close() {
    _socketSub?.cancel();
    return super.close();
  }

  Future<void> load() async {
    emit(state.copyWith(status: ThreadStatus.loading));
    final result = await _repository.getMessages(
      id: conversation.id,
      type: conversation.type,
    );
    switch (result) {
      case Success(value: final page):
        emit(state.copyWith(
          status: page.items.isEmpty ? ThreadStatus.empty : ThreadStatus.loaded,
          messages: page.items,
          hasMore: page.hasMore,
          nextBeforeId: page.nextBeforeId,
        ));
        _markRead();
      case Err(failure: final f):
        emit(state.copyWith(status: ThreadStatus.error, errorMessage: f.message));
    }
  }

  /// Loads an older page and prepends it (older messages sit above).
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.nextBeforeId == null) return;
    emit(state.copyWith(isLoadingMore: true));
    final result = await _repository.getMessages(
      id: conversation.id,
      type: conversation.type,
      beforeId: state.nextBeforeId,
    );
    switch (result) {
      case Success(value: final page):
        emit(state.copyWith(
          messages: [...page.items, ...state.messages],
          hasMore: page.hasMore,
          nextBeforeId: page.nextBeforeId,
          isLoadingMore: false,
        ));
      case Err():
        emit(state.copyWith(isLoadingMore: false, hasMore: false));
    }
  }

  /// Sends a text message.
  Future<void> send(String text) => _send(body: text.trim());

  /// Sends an image attachment (with optional caption).
  Future<void> sendImage(String imagePath, {String caption = ''}) =>
      _send(body: caption.trim(), imagePath: imagePath);

  /// Sends any file attachment — video or document (with optional caption). The
  /// server infers the kind (image|video|audio|file) from the file's mime type.
  Future<void> sendAttachment(String path, {String caption = ''}) =>
      _send(body: caption.trim(), imagePath: path);

  /// Shared send path; on success appends the created message to the bottom.
  Future<void> _send({String body = '', String? imagePath}) async {
    final hasImage = imagePath != null && imagePath.isNotEmpty;
    if ((body.isEmpty && !hasImage) || state.isSending || !canSend) return;
    emit(state.copyWith(isSending: true, clearError: true));
    final result = await _repository.sendMessage(
      id: conversation.id,
      type: conversation.type,
      body: body,
      imagePath: imagePath,
    );
    switch (result) {
      case Success(value: final message):
        emit(state.copyWith(
          messages: [...state.messages, message],
          status: ThreadStatus.loaded,
          isSending: false,
        ));
      case Err(failure: final f):
        emit(state.copyWith(isSending: false, errorMessage: f.message));
    }
  }

  /// Sends a location message (lat/lng + label).
  Future<Result<ChatMessage>> sendLocation(
      double lat, double lng, String label) async {
    final result = await _repository.sendMeta(
      conversationId: conversation.id,
      type: 'location',
      meta: {'lat': lat, 'lng': lng, 'label': label},
    );
    if (result case Success(value: final m)) {
      emit(state.copyWith(
          messages: [...state.messages, m], status: ThreadStatus.loaded));
    }
    return result;
  }

  /// Shares a contact (name + phone) as a message.
  Future<Result<ChatMessage>> sendContact(String name, String phone) async {
    final result = await _repository.sendMeta(
      conversationId: conversation.id,
      type: 'contact',
      meta: {'name': name, 'phone': phone},
    );
    if (result case Success(value: final m)) {
      emit(state.copyWith(
          messages: [...state.messages, m], status: ThreadStatus.loaded));
    }
    return result;
  }

  /// Blocks the other user in a direct chat.
  Future<Result<void>> blockPeer() async {
    final id = conversation.peerId;
    if (id == null) {
      return const Err(ValidationFailure('No user to block'));
    }
    return _repository.blockUser(id);
  }

  /// Edits a text message in place.
  Future<Result<ChatMessage>> editMessage(int messageId, String body) async {
    final result =
        await _repository.editMessage(conversation.id, messageId, body);
    if (result case Success(value: final updated)) {
      emit(state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == messageId) updated else m,
        ],
      ));
    }
    return result;
  }

  /// Deletes a message and removes it from the thread.
  Future<Result<void>> deleteMessage(int messageId) async {
    final result = await _repository.deleteMessage(conversation.id, messageId);
    if (result.isSuccess) {
      emit(state.copyWith(
        messages: state.messages.where((m) => m.id != messageId).toList(),
      ));
    }
    return result;
  }

  void _markRead() {
    if (conversation.type != ConversationType.broadcast) {
      _repository.markRead(conversation.id);
    }
  }
}
