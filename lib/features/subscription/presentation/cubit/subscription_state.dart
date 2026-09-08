part of 'subscription_cubit.dart';

enum SubStatus { initial, loading, loaded, error }

class SubscriptionState extends Equatable {
  const SubscriptionState({
    this.status = SubStatus.initial,
    this.subscription,
    this.plans = const [],
    this.requestingPlanId,
    this.errorMessage,
  });

  final SubStatus status;
  final Subscription? subscription;
  final List<SubscriptionPlan> plans;

  /// Id of the plan whose request is in flight (disables its button).
  final int? requestingPlanId;
  final String? errorMessage;

  /// Plans a user can request: active ones only, sorted by sort order.
  List<SubscriptionPlan> get selectablePlans =>
      (plans.where((p) => p.isActive).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));

  SubscriptionState copyWith({
    SubStatus? status,
    Subscription? subscription,
    List<SubscriptionPlan>? plans,
    int? requestingPlanId,
    bool clearRequesting = false,
    String? errorMessage,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      subscription: subscription ?? this.subscription,
      plans: plans ?? this.plans,
      requestingPlanId:
          clearRequesting ? null : (requestingPlanId ?? this.requestingPlanId),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, subscription, plans, requestingPlanId, errorMessage];
}
