import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// The per-period free-message allowance for a broadcast list, surfaced by the
/// API as `meta.broadcast_message_quota` on both GET and POST
/// `/broadcasts/{id}/messages`.
///
/// Once [used] reaches [freeLimit] (and the list isn't [isExempt]), each further
/// message costs [nextCreditCost] credits — which is where the credit-overage
/// confirmation kicks in.
class BroadcastQuota extends Equatable {
  const BroadcastQuota({
    required this.used,
    required this.freeLimit,
    required this.nextCreditCost,
    required this.isExempt,
  });

  final int used;
  final int freeLimit;
  final int nextCreditCost;
  final bool isExempt;

  /// True once the next message would be charged (free allowance spent and the
  /// list isn't exempt).
  bool get overFreeLimit => !isExempt && used >= freeLimit;

  factory BroadcastQuota.fromJson(Map<String, dynamic> json) => BroadcastQuota(
        used: json.asIntOr('used', 0),
        freeLimit: json.asIntOr('free_limit', 0),
        nextCreditCost: json.asIntOr('next_credit_cost', 0),
        isExempt: json.asBool('is_exempt'),
      );

  @override
  List<Object?> get props => [used, freeLimit, nextCreditCost, isExempt];
}
