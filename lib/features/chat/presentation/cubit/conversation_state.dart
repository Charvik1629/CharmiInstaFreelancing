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
    this.typingName,
    this.peerLastReadAt,
    this.peerOnline = false,
    this.peerLastSeen,
  });

  final ThreadStatus status;

  /// Ordered oldest → newest for display.
  final List<ChatMessage> messages;
  final bool hasMore;
  final int? nextBeforeId;
  final bool isLoadingMore;
  final bool isSending;
  final String? errorMessage;

  /// Name of the peer currently typing, or null. Drives the "typing…" header.
  final String? typingName;

  /// How far the peer has read (from `message:read`) — my messages up to this
  /// time show a "read" tick.
  final DateTime? peerLastReadAt;

  /// Peer online status + last-seen (direct chats), for the header subtitle.
  final bool peerOnline;
  final DateTime? peerLastSeen;

  ConversationState copyWith({
    ThreadStatus? status,
    List<ChatMessage>? messages,
    bool? hasMore,
    int? nextBeforeId,
    bool? isLoadingMore,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
    String? typingName,
    bool clearTyping = false,
    DateTime? peerLastReadAt,
    bool? peerOnline,
    DateTime? peerLastSeen,
  }) {
    return ConversationState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      nextBeforeId: nextBeforeId ?? this.nextBeforeId,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      typingName: clearTyping ? null : (typingName ?? this.typingName),
      peerLastReadAt: peerLastReadAt ?? this.peerLastReadAt,
      peerOnline: peerOnline ?? this.peerOnline,
      peerLastSeen: peerLastSeen ?? this.peerLastSeen,
    );
  }

  @override
  List<Object?> get props => [
        status,
        messages,
        hasMore,
        nextBeforeId,
        isLoadingMore,
        isSending,
        errorMessage,
        typingName,
        peerLastReadAt,
        peerOnline,
        peerLastSeen,
      ];
}
