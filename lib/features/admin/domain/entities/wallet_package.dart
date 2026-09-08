import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// A purchasable credit package (admin view — includes inactive packages).
class WalletPackage extends Equatable {
  const WalletPackage({
    required this.id,
    required this.name,
    this.credits = 0,
    this.amountPaise = 0,
    this.currency = 'INR',
    this.isActive = true,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final int credits;
  final int amountPaise;
  final String currency;
  final bool isActive;
  final int sortOrder;

  /// Price in rupees (₹). `amount_paise` is the source of truth.
  double get amount => amountPaise / 100.0;

  factory WalletPackage.fromJson(Map<String, dynamic> json) => WalletPackage(
        id: json.asIntOr('id', 0),
        name: json.asStringOr('name', ''),
        credits: json.asIntOr('credits', 0),
        amountPaise: json.asIntOr('amount_paise', 0),
        currency: json.asStringOr('currency', 'INR'),
        isActive: json.asBool('is_active', fallback: true),
        sortOrder: json.asIntOr('sort_order', 0),
      );

  @override
  List<Object?> get props =>
      [id, name, credits, amountPaise, currency, isActive, sortOrder];
}
