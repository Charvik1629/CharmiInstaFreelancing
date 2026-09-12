import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// An order (`POST /orders`). Settled in credits; the design shows it as a card
/// inside a chat. Status flows pending → paid/in-progress → completed.
class AppOrder extends Equatable {
  const AppOrder({
    required this.id,
    this.number,
    this.status = 'pending',
    this.amountCredits = 0,
    this.currency = 'INR',
    this.title,
    this.notes,
    this.conversationId,
    this.createdAt,
  });

  final int id;
  final String? number;
  final String status;
  final int amountCredits;
  final String currency;
  final String? title;
  final String? notes;
  final int? conversationId;
  final DateTime? createdAt;

  factory AppOrder.fromJson(Map<String, dynamic> json) {
    final load = json.asMap('load');
    return AppOrder(
      id: json.asIntOr('id', 0),
      number: json.asString('number'),
      status: json.asStringOr('status', 'pending'),
      amountCredits: json.asIntOr('amount_credits', 0),
      currency: json.asStringOr('currency', 'INR'),
      title: json.asString('title') ?? load?.asString('title'),
      notes: json.asString('notes'),
      conversationId: json.asInt('conversation_id'),
      createdAt: json.asDate('created_at'),
    );
  }

  @override
  List<Object?> get props =>
      [id, number, status, amountCredits, currency, title, notes, conversationId, createdAt];
}
