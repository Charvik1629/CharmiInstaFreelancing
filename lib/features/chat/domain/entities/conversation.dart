import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';
import 'chat_label.dart';

/// The three kinds of chat in Nexveero:
/// - [direct]  — one-to-one (from GET /chats, type "direct")
/// - [group]   — many-to-many group (from GET /chats, type "group")
/// - [broadcast] — one-to-many announcement list (from GET /broadcasts)
enum ConversationType {
  direct,
  group,
  broadcast;

  static ConversationType fromApi(String? raw) => switch (raw) {
        'group' => ConversationType.group,
        'broadcast' => ConversationType.broadcast,
        _ => ConversationType.direct,
      };
}

/// A single inbox row, normalized so direct/group (GET /chats) and broadcast
/// (GET /broadcasts) — which have different JSON shapes — render through one
/// widget and one list.
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.avatarUrl,
    this.peerId,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.canChat = true,
    this.isPinned = false,
    this.labels = const [],
  });

  /// For direct/group this is the conversation id (used by
  /// /conversations/{id}/…). For broadcast it is the broadcast-list id (used by
  /// /broadcasts/{id}/…). [type] tells callers which endpoint family to use.
  final int id;
  final ConversationType type;
  final String title;
  final String? subtitle;
  final String? avatarUrl;

  /// The other user's id for a direct chat (used for block/profile). Null for
  /// groups and broadcasts.
  final int? peerId;

  /// A short preview of the last message (already collapsed from body /
  /// attachment). Null when the thread has no messages yet.
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool canChat;

  /// Pinned conversations sort to the top of the inbox.
  final bool isPinned;

  /// Labels attached to this conversation (direct/group only).
  final List<ChatLabel> labels;

  bool get hasUnread => unreadCount > 0;
  bool get isBroadcast => type == ConversationType.broadcast;

  /// Parses a GET /chats item (direct or group).
  factory Conversation.fromChatJson(Map<String, dynamic> json) {
    final last = json.asMap('last_message');
    return Conversation(
      id: json.asIntOr('conversation_id', json.asIntOr('id', 0)),
      type: ConversationType.fromApi(json.asString('type')),
      title: json.asStringOr('title', 'Conversation'),
      subtitle: json.asString('subtitle'),
      avatarUrl: json.asString('avatar_url') ??
          json.asMap('peer')?.asString('avatar_url'),
      peerId: json.asMap('peer')?.asInt('id'),
      lastMessage: _preview(last),
      lastMessageAt: last?.asDate('created_at'),
      unreadCount: json.asIntOr('unread_count', 0),
      canChat: json.asBool('can_chat', fallback: true),
      isPinned: json.asBool('is_pinned'),
      labels: _labelsFrom(json['labels']),
    );
  }

  static List<ChatLabel> _labelsFrom(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map<String, dynamic>) ChatLabel.fromJson(e),
    ];
  }

  /// Parses a POST /chats response (start/reopen a 1:1) into a Conversation
  /// good enough to open the thread: id + peer name/avatar.
  factory Conversation.fromStartChatJson(Map<String, dynamic> json) {
    final peer = json.asMap('peer');
    return Conversation(
      id: json.asIntOr('conversation_id', json.asIntOr('id', 0)),
      type: ConversationType.fromApi(json.asString('type')),
      title: peer?.asStringOr('name', 'Chat') ?? 'Chat',
      avatarUrl: peer?.asString('avatar_url'),
      peerId: peer?.asInt('id'),
      canChat: true,
    );
  }

  /// Parses a GET /broadcasts item (broadcast list) into the same shape.
  factory Conversation.fromBroadcastJson(Map<String, dynamic> json) {
    final last = json.asMap('last_message');
    final recipients = json.asIntOr('recipient_count', 0);
    return Conversation(
      id: json.asIntOr('id', 0),
      type: ConversationType.broadcast,
      title: json.asStringOr('name', 'Broadcast'),
      subtitle: '$recipients recipient${recipients == 1 ? '' : 's'}',
      avatarUrl: json.asString('avatar_url'),
      lastMessage: _preview(last),
      lastMessageAt: last?.asDate('created_at'),
      canChat: true,
    );
  }

  /// Collapses a last_message object to a preview string. A null body with an
  /// image attachment becomes "📷 Photo".
  static String? _preview(Map<String, dynamic>? last) {
    if (last == null) return null;
    final body = last.asString('body');
    if (body != null && body.isNotEmpty) return body;
    final attachments = last['attachments'];
    if (attachments is List && attachments.isNotEmpty) {
      final kind = attachments.first is Map
          ? (attachments.first as Map)['kind']
          : null;
      return kind == 'image' ? '📷 Photo' : '📎 Attachment';
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        subtitle,
        avatarUrl,
        peerId,
        lastMessage,
        lastMessageAt,
        unreadCount,
        canChat,
        isPinned,
        labels,
      ];
}
