import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/repositories/subscription_repository.dart';

part 'subscription_state.dart';

/// Drives the user's Subscription screen: current status + available plans, and
/// requesting a plan (which creates a pending admin request).
class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit(this._repository) : super(const SubscriptionState());

  final SubscriptionRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: SubStatus.loading));
    final results = await Future.wait([
      _repository.getSubscription(),
      _repository.getPlans(),
    ]);
    final subRes = results[0] as Result<Subscription>;
    final plansRes = results[1] as Result<List<SubscriptionPlan>>;

    if (subRes case Success(value: final sub)) {
      final plans = switch (plansRes) {
        Success(value: final p) => p,
        _ => state.plans,
      };
      emit(state.copyWith(
        status: SubStatus.loaded,
        subscription: sub,
        plans: plans,
      ));
    } else {
      emit(state.copyWith(
        status: SubStatus.error,
        errorMessage: subRes.failureOrNull?.message ?? 'Could not load',
      ));
    }
  }

  Future<void> refresh() => load();

  /// Requests a plan. On success, reloads the subscription so the pending
  /// request appears. Returns whether it succeeded.
  Future<bool> requestPlan(SubscriptionPlan plan) async {
    if (state.requestingPlanId != null) return false;
    emit(state.copyWith(requestingPlanId: plan.id));
    final result = await _repository.requestPlan(plan.id);
    switch (result) {
      case Success():
        final subRes = await _repository.getSubscription();
        emit(state.copyWith(
          subscription: subRes.valueOrNull ?? state.subscription,
          clearRequesting: true,
        ));
        return true;
      case Err(failure: final f):
        emit(state.copyWith(
          errorMessage: f.message,
          clearRequesting: true,
        ));
        return false;
    }
  }
}
