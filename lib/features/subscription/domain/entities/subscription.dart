import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';
import 'subscription_plan.dart';
import 'subscription_request.dart';

/// The current user's subscription state (`GET /subscription`).
///
/// [enabled] is the global enforcement flag (admin setting). [status] is the
/// user's standing: typically `active`, `required` (must subscribe to use the
/// app), or `none`.
class Subscription extends Equatable {
  const Subscription({
    this.enabled = false,
    this.status = 'none',
    this.plan,
    this.startedAt,
    this.endsAt,
    this.pendingRequest,
  });

  final bool enabled;
  final String status;
  final SubscriptionPlan? plan;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final SubscriptionRequest? pendingRequest;

  bool get isActive => status == 'active';

  /// Enforcement is on and the user has not subscribed yet.
  bool get isRequired => enabled && status == 'required';

  bool get hasPendingRequest =>
      pendingRequest != null && pendingRequest!.isPending;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final planJson = json.asMap('plan');
    final reqJson = json.asMap('pending_request');
    return Subscription(
      enabled: json.asBool('enabled'),
      status: json.asStringOr('status', 'none'),
      plan: planJson == null ? null : SubscriptionPlan.fromJson(planJson),
      startedAt: json.asDate('started_at'),
      endsAt: json.asDate('ends_at'),
      pendingRequest:
          reqJson == null ? null : SubscriptionRequest.fromJson(reqJson),
    );
  }

  @override
  List<Object?> get props =>
      [enabled, status, plan, startedAt, endsAt, pendingRequest];
}
