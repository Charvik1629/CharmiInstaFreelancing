import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// The per-period free allowance for broadcasts, surfaced by the API as:
/// - `meta.broadcast_message_quota` on GET/POST `/broadcasts/{id}/messages`
///   (how many broadcast MESSAGES can be sent this window), and
/// - `meta.broadcast_list_quota` on GET/POST `/broadcasts`
///   (how many broadcast LISTS can be created this window).
///
/// Once [used] reaches [freeLimit] (and the caller isn't [isExempt]), each
/// further action costs [nextCreditCost] credits — which is where the
/// credit-overage confirmation kicks in. [remaining] is derived (the API has no
/// explicit field): `max(0, freeLimit - used)`.
class BroadcastQuota extends Equatable {
  const BroadcastQuota({
    required this.used,
    required this.freeLimit,
    required this.nextCreditCost,
    required this.isExempt,
    this.period,
    this.windowStartedAt,
  });

  final int used;
  final int freeLimit;
  final int nextCreditCost;
  final bool isExempt;

  /// Rolling window the allowance resets on: `daily`, `weekly`, `monthly`, …
  final String? period;

  /// Start of the current window.
  final DateTime? windowStartedAt;

  /// Free actions left this window (derived — not a named API field).
  int get remaining => (freeLimit - used) > 0 ? freeLimit - used : 0;

  /// True once the next action would be charged (free allowance spent and the
  /// caller isn't exempt).
  bool get overFreeLimit => !isExempt && used >= freeLimit;

  factory BroadcastQuota.fromJson(Map<String, dynamic> json) => BroadcastQuota(
        used: json.asIntOr('used', 0),
        freeLimit: json.asIntOr('free_limit', 0),
        nextCreditCost: json.asIntOr('next_credit_cost', 0),
        isExempt: json.asBool('is_exempt'),
        period: json.asString('period'),
        windowStartedAt: json.asDate('window_started_at'),
      );

  @override
  List<Object?> get props =>
      [used, freeLimit, nextCreditCost, isExempt, period, windowStartedAt];
}
