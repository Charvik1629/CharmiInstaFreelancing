import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';

part 'conversation_state.dart';

/// Drives a single thread (direct, group or broadcast). Loads the most recent
/// window of messages, pages older ones on demand, and sends new ones.
class ConversationCubit extends Cubit<ConversationState> {
  ConversationCubit(this._repository, this.conversation, {this.meId})
      : super(const ConversationState());

  final ChatRepository _repository;
  final Conversation conversation;
  final int? meId;

  bool get canSend => conversation.canChat;

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

  void _markRead() {
    if (conversation.type != ConversationType.broadcast) {
      _repository.markRead(conversation.id);
    }
  }
}
