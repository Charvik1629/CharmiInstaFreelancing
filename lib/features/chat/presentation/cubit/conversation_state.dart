part of 'conversation_cubit.dart';

enum ThreadStatus { initial, loading, loaded, empty, error }

class ConversationState extends Equatable {
  const ConversationState({
    this.status = ThreadStatus.initial,
    this.messages = const [],
    this.hasMore = false,
    this.nextBeforeId,
    this.isLoadingMore = false,
    this.isSending = false,
    this.errorMessage,
  });

  final ThreadStatus status;

  /// Ordered oldest → newest for display.
  final List<ChatMessage> messages;
  final bool hasMore;
  final int? nextBeforeId;
  final bool isLoadingMore;
  final bool isSending;
  final String? errorMessage;

  ConversationState copyWith({
    ThreadStatus? status,
    List<ChatMessage>? messages,
    bool? hasMore,
    int? nextBeforeId,
    bool? isLoadingMore,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ConversationState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      nextBeforeId: nextBeforeId ?? this.nextBeforeId,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, messages, hasMore, nextBeforeId, isLoadingMore, isSending, errorMessage];
}
