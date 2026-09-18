import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// A party (buyer or seller) on an order.
class OrderParty extends Equatable {
  const OrderParty({required this.id, this.name, this.businessName});

  final int id;
  final String? name;
  final String? businessName;

  String get displayName =>
      (businessName != null && businessName!.isNotEmpty)
          ? businessName!
          : (name ?? 'User');

  factory OrderParty.fromJson(Map<String, dynamic> json) => OrderParty(
        id: json.asIntOr('id', 0),
        name: json.asString('name'),
        businessName: json.asString('business_name'),
      );

  @override
  List<Object?> get props => [id, name, businessName];
}

/// An order (`GET/POST /orders`). A shared buy/sell record settled in credits.
/// Status flows: pending → confirmed → paid → completed (or cancelled/refunded).
class AppOrder extends Equatable {
  const AppOrder({
    required this.id,
    this.number,
    this.status = 'pending',
    this.amountCredits = 0,
    this.currency = 'INR',
    this.title,
    this.notes,
    this.buyer,
    this.seller,
    this.loadId,
    this.conversationId,
    this.paidAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String? number;
  final String status;
  final int amountCredits;
  final String currency;

  /// Load title (orders have no title of their own — shown as the subject).
  final String? title;
  final String? notes;

  final OrderParty? buyer;
  final OrderParty? seller;
  final int? loadId;
  final int? conversationId;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPaid => paidAt != null || status == 'paid' || status == 'completed';
  bool get isCancelled => status == 'cancelled' || status == 'refunded';

  /// The buyer can pay while the order is still pending or confirmed.
  bool canPay(int? meId) =>
      meId != null &&
      buyer?.id == meId &&
      (status == 'pending' || status == 'confirmed');

  /// The seller confirms a pending order.
  bool canConfirm(int? meId) =>
      meId != null && seller?.id == meId && status == 'pending';

  /// Either party can cancel while unpaid, or complete once paid.
  bool canCancel(int? meId) =>
      _isParty(meId) && (status == 'pending' || status == 'confirmed');
  bool canComplete(int? meId) => _isParty(meId) && status == 'paid';

  bool _isParty(int? meId) =>
      meId != null && (buyer?.id == meId || seller?.id == meId);

  /// The other side of the order relative to [meId] (for the header).
  OrderParty? counterparty(int? meId) =>
      buyer?.id == meId ? seller : buyer;

  factory AppOrder.fromJson(Map<String, dynamic> json) {
    final load = json.asMap('load');
    final buyer = json.asMap('buyer');
    final seller = json.asMap('seller');
    return AppOrder(
      id: json.asIntOr('id', 0),
      number: json.asString('number'),
      status: json.asStringOr('status', 'pending'),
      amountCredits: json.asIntOr('amount_credits', 0),
      currency: json.asStringOr('currency', 'INR'),
      title: json.asString('title') ?? load?.asString('title'),
      notes: json.asString('notes'),
      buyer: buyer != null ? OrderParty.fromJson(buyer) : null,
      seller: seller != null ? OrderParty.fromJson(seller) : null,
      loadId: load?.asInt('id') ?? json.asInt('load_id'),
      conversationId: json.asInt('conversation_id'),
      paidAt: json.asDate('paid_at'),
      createdAt: json.asDate('created_at'),
      updatedAt: json.asDate('updated_at'),
    );
  }

  @override
  List<Object?> get props => [
        id,
        number,
        status,
        amountCredits,
        currency,
        title,
        notes,
        buyer,
        seller,
        loadId,
        conversationId,
        paidAt,
        createdAt,
        updatedAt,
      ];
}
