import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// One message in a thread (direct/group/broadcast share this shape).
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.body,
    this.senderId,
    this.senderName,
    this.imageUrl,
    this.attachmentKind,
    this.attachmentUrl,
    this.attachmentName,
    this.isBroadcast = false,
    this.createdAt,
  });

  final int id;
  final String? body;
  final int? senderId;
  final String? senderName;

  /// First image attachment url, if any (server-relative). Kept for the inline
  /// image bubble.
  final String? imageUrl;

  /// First attachment of any kind: `image` | `video` | `audio` | `file`.
  final String? attachmentKind;
  final String? attachmentUrl;
  final String? attachmentName;

  final bool isBroadcast;
  final DateTime? createdAt;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// A non-image attachment (video/audio/file) that renders as a chip.
  bool get hasFileAttachment =>
      attachmentKind != null &&
      attachmentKind != 'image' &&
      (attachmentUrl?.isNotEmpty ?? false);

  /// True when this message was sent by [meId] (drives bubble alignment).
  bool isMine(int? meId) => meId != null && senderId == meId;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json.asMap('sender');
    final attachments = json['attachments'];
    String? image;
    String? kind, url, name;
    if (attachments is List) {
      for (final a in attachments) {
        if (a is! Map) continue;
        kind ??= a['kind'] as String?;
        url ??= a['url'] as String?;
        name ??= a['original_name'] as String?;
        if (a['kind'] == 'image' && a['url'] is String) {
          image = a['url'] as String;
          break;
        }
      }
    }
    return ChatMessage(
      id: json.asIntOr('id', 0),
      body: json.asString('body'),
      senderId: sender?.asInt('id'),
      senderName: sender?.asString('name'),
      imageUrl: image,
      attachmentKind: kind,
      attachmentUrl: url,
      attachmentName: name,
      isBroadcast: json.asBool('is_broadcast'),
      createdAt: json.asDate('created_at'),
    );
  }

  @override
  List<Object?> get props => [
        id,
        body,
        senderId,
        senderName,
        imageUrl,
        attachmentKind,
        attachmentUrl,
        attachmentName,
        isBroadcast,
        createdAt,
      ];
}
