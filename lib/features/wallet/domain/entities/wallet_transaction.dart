import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// A single wallet ledger entry (GET /wallet/transactions).
class WalletTransaction extends Equatable {
  const WalletTransaction({
    required this.id,
    required this.isCredit,
    this.reason,
    this.amount = 0,
    this.balanceAfter,
    this.createdAt,
  });

  final int id;

  /// true = credit (+), false = debit (−).
  final bool isCredit;

  /// Raw reason code, e.g. `post_load`, `demo_topup`, `boost_load`.
  final String? reason;
  final int amount;
  final int? balanceAfter;
  final DateTime? createdAt;

  /// Human-friendly label from the reason code.
  String get label => switch (reason) {
        'post_load' => 'Posted a listing',
        'boost_load' => 'Boosted a post',
        'broadcast' => 'Broadcast sent',
        'demo_topup' => 'Demo top-up',
        'topup' => 'Wallet top-up',
        'purchase' => 'Credit purchase',
        _ => (reason ?? 'Transaction').replaceAll('_', ' '),
      };

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json.asIntOr('id', 0),
        isCredit: json.asString('type') == 'credit',
        reason: json.asString('reason'),
        amount: json.asIntOr('amount', 0),
        balanceAfter: json.asInt('balance_after'),
        createdAt: json.asDate('created_at'),
      );

  @override
  List<Object?> get props => [id, isCredit, reason, amount, balanceAfter, createdAt];
}
