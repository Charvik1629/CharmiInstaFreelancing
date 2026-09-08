import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// Wallet summary (GET /wallet): the credit balance, what actions cost, and how
/// top-ups are available (real Razorpay vs a demo top-up).
class Wallet extends Equatable {
  const Wallet({
    this.creditBalance = 0,
    this.postCost = 0,
    this.boostCost = 0,
    this.businessBoostCost = 0,
    this.broadcastCost = 0,
    this.currency = 'INR',
    this.razorpayConfigured = false,
    this.demoTopupEnabled = false,
    this.demoTopupCredits = 0,
  });

  final int creditBalance;
  final int postCost;
  final int boostCost;
  final int businessBoostCost;
  final int broadcastCost;
  final String currency;
  final bool razorpayConfigured;
  final bool demoTopupEnabled;
  final int demoTopupCredits;

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        creditBalance: json.asIntOr('credit_balance', 0),
        postCost: json.asIntOr('post_credit_cost', 0),
        boostCost: json.asIntOr('boost_credit_cost', 0),
        businessBoostCost: json.asIntOr('business_boost_credit_cost', 0),
        broadcastCost: json.asIntOr('broadcast_credit_cost', 0),
        currency: json.asStringOr('currency', 'INR'),
        razorpayConfigured: json.asBool('razorpay_configured'),
        demoTopupEnabled: json.asBool('demo_topup_enabled'),
        demoTopupCredits: json.asIntOr('demo_topup_credits', 0),
      );

  @override
  List<Object?> get props => [
        creditBalance,
        postCost,
        boostCost,
        businessBoostCost,
        broadcastCost,
        currency,
        razorpayConfigured,
        demoTopupEnabled,
        demoTopupCredits,
      ];
}

/// A purchasable credit bundle (GET /wallet/packages).
class CreditPackage extends Equatable {
  const CreditPackage({
    required this.id,
    required this.name,
    required this.credits,
    required this.amount,
    this.currency = 'INR',
  });

  final int id;
  final String name;
  final int credits;
  final double amount;
  final String currency;

  factory CreditPackage.fromJson(Map<String, dynamic> json) => CreditPackage(
        id: json.asIntOr('id', 0),
        name: json.asStringOr('name', ''),
        credits: json.asIntOr('credits', 0),
        amount: (json['amount'] is num)
            ? (json['amount'] as num).toDouble()
            : double.tryParse('${json['amount']}') ?? 0,
        currency: json.asStringOr('currency', 'INR'),
      );

  @override
  List<Object?> get props => [id, name, credits, amount, currency];
}
