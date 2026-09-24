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
    this.broadcastQuota,
    this.broadcastLimitReached = false,
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

  /// Broadcast free-message allowance (broadcast threads only; null otherwise).
  final BroadcastQuota? broadcastQuota;

  /// Set when a broadcast send was rejected with the quota-403 ("limit over ·
  /// subscribe"). The page consumes it to raise the unfunded overage dialog,
  /// then clears it.
  final bool broadcastLimitReached;

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
    BroadcastQuota? broadcastQuota,
    bool? broadcastLimitReached,
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
      broadcastQuota: broadcastQuota ?? this.broadcastQuota,
      broadcastLimitReached:
          broadcastLimitReached ?? this.broadcastLimitReached,
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
        broadcastQuota,
        broadcastLimitReached,
      ];
}
