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
    this.isSystem = false,
    this.isStarred = false,
    this.isInquiry = false,
    this.inquiryPrice,
    this.isLocation = false,
    this.locationLabel,
    this.latitude,
    this.longitude,
    this.conversationId,
    this.order,
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

  /// A server-generated event line (`type: "system"`), e.g. "X requested load …"
  /// or "Y made an offer …" — rendered as a centered banner, not a bubble.
  final bool isSystem;

  /// Whether the current user has starred this message.
  final bool isStarred;

  /// A one-to-one Inquiry card (`type: "inquiry"`) — renders as a special
  /// bubble with the question and an optional price.
  final bool isInquiry;

  /// Formatted INR price for an inquiry (`meta.price_formatted`, e.g. "₹1,499").
  final String? inquiryPrice;

  /// A shared location card (`type: "location"`) — renders as a pin + label,
  /// tappable to open the coordinates in a maps app.
  final bool isLocation;

  /// Optional place label for a location message (`meta.label`).
  final String? locationLabel;

  /// Coordinates for a location message (`meta.lat` / `meta.lng`).
  final double? latitude;
  final double? longitude;

  /// Owning conversation id (set on the starred-messages list, for navigation).
  final int? conversationId;

  /// Order payload when this message is an order card (`type: "order"`).
  final MessageOrder? order;

  final DateTime? createdAt;

  bool get isOrder => order != null;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// A non-image attachment (video/audio/file) that renders as a chip.
  bool get hasFileAttachment =>
      attachmentKind != null &&
      attachmentKind != 'image' &&
      (attachmentUrl?.isNotEmpty ?? false);

  /// True when this message was sent by [meId] (drives bubble alignment).
  bool isMine(int? meId) => meId != null && senderId == meId;

  ChatMessage copyWith({bool? isStarred}) => ChatMessage(
        id: id,
        body: body,
        senderId: senderId,
        senderName: senderName,
        imageUrl: imageUrl,
        attachmentKind: attachmentKind,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        isBroadcast: isBroadcast,
        isSystem: isSystem,
        isStarred: isStarred ?? this.isStarred,
        isInquiry: isInquiry,
        inquiryPrice: inquiryPrice,
        isLocation: isLocation,
        locationLabel: locationLabel,
        latitude: latitude,
        longitude: longitude,
        conversationId: conversationId,
        order: order,
        createdAt: createdAt,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json.asMap('sender');
    final orderJson = json.asMap('order');
    final type = json.asString('type');
    final meta = json.asMap('meta');
    final isOrderType = type == 'order' || orderJson != null;
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
      isSystem: type == 'system',
      isStarred: json.asBool('is_starred'),
      isInquiry: type == 'inquiry',
      inquiryPrice: meta?.asString('price_formatted'),
      isLocation: type == 'location',
      locationLabel: meta?.asString('label'),
      latitude: meta?.asDouble('lat'),
      longitude: meta?.asDouble('lng'),
      conversationId: json.asInt('conversation_id'),
      order: isOrderType ? MessageOrder.fromJson(orderJson ?? json) : null,
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
        isSystem,
        isStarred,
        isInquiry,
        inquiryPrice,
        isLocation,
        locationLabel,
        latitude,
        longitude,
        conversationId,
        order,
        createdAt,
      ];
}

/// Order payload attached to an order-type chat message (design "Chat · Order
/// cards"). Fields are parsed defensively since the backend message shape for
/// orders isn't finalised.
class MessageOrder extends Equatable {
  const MessageOrder({
    required this.id,
    this.number,
    this.status = 'pending',
    this.amountCredits = 0,
    this.title,
  });

  final int id;
  final String? number;
  final String status;
  final int amountCredits;
  final String? title;

  factory MessageOrder.fromJson(Map<String, dynamic> json) {
    final load = json.asMap('load');
    return MessageOrder(
      id: json.asIntOr('id', 0),
      number: json.asString('number'),
      status: json.asStringOr('status', 'pending'),
      amountCredits: json.asIntOr('amount_credits', 0),
      title: json.asString('title') ?? load?.asString('title'),
    );
  }

  @override
  List<Object?> get props => [id, number, status, amountCredits, title];
}
