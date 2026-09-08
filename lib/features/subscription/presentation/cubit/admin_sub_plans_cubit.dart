import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/repositories/admin_subscription_repository.dart';

part 'admin_sub_plans_state.dart';

/// Admin management of subscription plans plus the global enforcement toggle
/// (`subscription_enabled`). Loads both together; supports create / update /
/// delete of plans and flipping enforcement.
class AdminSubPlansCubit extends Cubit<AdminSubPlansState> {
  AdminSubPlansCubit(this._repository) : super(const AdminSubPlansState());

  final AdminSubscriptionRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: PlansStatus.loading));
    final results = await Future.wait([
      _repository.getPlans(),
      _repository.getEnforcement(),
    ]);
    final plansRes = results[0] as Result<List<SubscriptionPlan>>;
    final enforceRes = results[1] as Result<bool>;

    if (plansRes case Success(value: final plans)) {
      final sorted = [...plans]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      emit(state.copyWith(
        status: PlansStatus.loaded,
        plans: sorted,
        enforcementEnabled: enforceRes.valueOrNull ?? state.enforcementEnabled,
      ));
    } else {
      emit(state.copyWith(
        status: PlansStatus.error,
        errorMessage: plansRes.failureOrNull?.message ?? 'Could not load plans',
      ));
    }
  }

  Future<void> refresh() => load();

  Future<void> setEnforcement(bool enabled) async {
    final previous = state.enforcementEnabled;
    emit(state.copyWith(enforcementEnabled: enabled, savingEnforcement: true));
    final result = await _repository.setEnforcement(enabled);
    switch (result) {
      case Success(value: final v):
        emit(state.copyWith(enforcementEnabled: v, savingEnforcement: false));
      case Err(failure: final f):
        // Revert the optimistic flip on failure.
        emit(state.copyWith(
          enforcementEnabled: previous,
          savingEnforcement: false,
          errorMessage: f.message,
        ));
    }
  }

  Future<bool> createPlan({
    required String name,
    String? description,
    required int durationDays,
    required bool isActive,
    required int sortOrder,
  }) async {
    final result = await _repository.createPlan(
      name: name,
      description: description,
      durationDays: durationDays,
      isActive: isActive,
      sortOrder: sortOrder,
    );
    if (result case Success(value: final plan)) {
      final plans = [...state.plans, plan]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      emit(state.copyWith(plans: plans, status: PlansStatus.loaded));
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }

  Future<bool> updatePlan({
    required int id,
    required String name,
    String? description,
    required int durationDays,
    required bool isActive,
    required int sortOrder,
  }) async {
    final result = await _repository.updatePlan(
      id: id,
      name: name,
      description: description,
      durationDays: durationDays,
      isActive: isActive,
      sortOrder: sortOrder,
    );
    if (result case Success(value: final plan)) {
      final plans = state.plans.map((p) => p.id == id ? plan : p).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      emit(state.copyWith(plans: plans));
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }

  Future<bool> deletePlan(int id) async {
    final result = await _repository.deletePlan(id);
    if (result.isSuccess) {
      final plans = state.plans.where((p) => p.id != id).toList();
      emit(state.copyWith(
        plans: plans,
        status: plans.isEmpty ? PlansStatus.empty : PlansStatus.loaded,
      ));
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }
}
