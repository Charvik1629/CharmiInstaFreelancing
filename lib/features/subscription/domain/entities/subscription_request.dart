import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';
import '../../../../core/models/user.dart';
import 'subscription_plan.dart';

/// A user's request to subscribe to a plan, pending admin review. [user] is
/// present in the admin requests list (`GET /admin/subscriptions/requests`).
class SubscriptionRequest extends Equatable {
  const SubscriptionRequest({
    required this.id,
    required this.status,
    this.adminNote,
    this.plan,
    this.user,
    this.reviewedAt,
    this.createdAt,
  });

  final int id;

  /// `pending`, `approved`, or `rejected`.
  final String status;
  final String? adminNote;
  final SubscriptionPlan? plan;
  final User? user;
  final DateTime? reviewedAt;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';

  factory SubscriptionRequest.fromJson(Map<String, dynamic> json) {
    final planJson = json.asMap('plan');
    final userJson = json.asMap('user');
    return SubscriptionRequest(
      id: json.asIntOr('id', 0),
      status: json.asStringOr('status', 'pending'),
      adminNote: json.asString('admin_note'),
      plan: planJson == null ? null : SubscriptionPlan.fromJson(planJson),
      user: userJson == null ? null : User.fromJson(userJson),
      reviewedAt: json.asDate('reviewed_at'),
      createdAt: json.asDate('created_at'),
    );
  }

  @override
  List<Object?> get props =>
      [id, status, adminNote, plan, user, reviewedAt, createdAt];
}
