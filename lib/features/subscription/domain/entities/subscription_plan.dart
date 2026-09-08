import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// A subscription plan offered to users. Plans have no price in the API —
/// access is admin-granted (request → admin approves), gated only by duration.
class SubscriptionPlan extends Equatable {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    this.description,
    this.durationDays = 0,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final String? description;
  final int durationDays;
  final bool isActive;
  final int sortOrder;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        id: json.asIntOr('id', 0),
        name: json.asStringOr('name', ''),
        description: json.asString('description'),
        durationDays: json.asIntOr('duration_days', 0),
        isActive: json.asBool('is_active', fallback: true),
        sortOrder: json.asIntOr('sort_order', 0),
      );

  @override
  List<Object?> get props =>
      [id, name, description, durationDays, isActive, sortOrder];
}
