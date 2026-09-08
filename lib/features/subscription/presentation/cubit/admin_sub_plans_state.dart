part of 'admin_sub_plans_cubit.dart';

enum PlansStatus { initial, loading, loaded, empty, error }

class AdminSubPlansState extends Equatable {
  const AdminSubPlansState({
    this.status = PlansStatus.initial,
    this.plans = const [],
    this.enforcementEnabled = false,
    this.savingEnforcement = false,
    this.errorMessage,
  });

  final PlansStatus status;
  final List<SubscriptionPlan> plans;
  final bool enforcementEnabled;
  final bool savingEnforcement;
  final String? errorMessage;

  AdminSubPlansState copyWith({
    PlansStatus? status,
    List<SubscriptionPlan>? plans,
    bool? enforcementEnabled,
    bool? savingEnforcement,
    String? errorMessage,
  }) {
    return AdminSubPlansState(
      status: status ?? this.status,
      plans: plans ?? this.plans,
      enforcementEnabled: enforcementEnabled ?? this.enforcementEnabled,
      savingEnforcement: savingEnforcement ?? this.savingEnforcement,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, plans, enforcementEnabled, savingEnforcement, errorMessage];
}
