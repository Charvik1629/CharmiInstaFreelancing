import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// An offer made on a load (GET /offers). Carries who/what/how-much plus the
/// chat it opened, so the list can deep-link into the conversation.
class Offer extends Equatable {
  const Offer({
    required this.id,
    required this.loadId,
    this.body,
    this.priceFormatted,
    this.loadTitle,
    this.otherPartyName,
    this.otherPartyAvatar,
    this.conversationId,
    this.isReceived = false,
    this.isOwnOffer = false,
    this.createdAt,
  });

  final int id;
  final int loadId;

  /// The offer remarks.
  final String? body;

  /// Human-formatted amount, e.g. "15,000.00".
  final String? priceFormatted;
  final String? loadTitle;

  /// The other side of the offer (for a received offer that's the sender; for a
  /// sent offer, the load's author).
  final String? otherPartyName;
  final String? otherPartyAvatar;
  final int? conversationId;

  final bool isReceived;
  final bool isOwnOffer;
  final DateTime? createdAt;

  factory Offer.fromJson(Map<String, dynamic> json) {
    final user = json.asMap('user');
    final load = json.asMap('load');
    final author = load?.asMap('author');
    final isReceived = json.asBool('is_received');
    // Received → show the offering user; sent → show the load's author.
    final other = isReceived ? user : author;
    return Offer(
      id: json.asIntOr('id', 0),
      loadId: json.asIntOr('load_id', 0),
      body: json.asString('body'),
      priceFormatted: json.asString('price_formatted') ?? json.asString('price'),
      loadTitle: load?.asString('title'),
      otherPartyName: other?.asString('name'),
      otherPartyAvatar: other?.asString('avatar_url'),
      conversationId: json.asInt('conversation_id'),
      isReceived: isReceived,
      isOwnOffer: json.asBool('is_own_offer'),
      createdAt: json.asDate('created_at'),
    );
  }

  @override
  List<Object?> get props =>
      [id, loadId, body, priceFormatted, loadTitle, otherPartyName, conversationId, isReceived];
}
