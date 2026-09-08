import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/sub_request_status.dart';
import '../../domain/entities/subscription_request.dart';
import '../../domain/repositories/admin_subscription_repository.dart';

part 'admin_sub_requests_state.dart';

/// Admin queue of subscription requests: Pending / Approved / Rejected tabs with
/// per-request Approve / Reject. Approving grants the user's subscription.
class AdminSubRequestsCubit extends Cubit<AdminSubRequestsState> {
  AdminSubRequestsCubit(this._repository) : super(const AdminSubRequestsState());

  final AdminSubscriptionRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: ReqStatus.loading));
    final result = await _repository.getRequests(state.filter);
    switch (result) {
      case Success(value: final items):
        emit(state.copyWith(
          status: items.isEmpty ? ReqStatus.empty : ReqStatus.loaded,
          requests: items,
        ));
      case Err(failure: final f):
        emit(state.copyWith(status: ReqStatus.error, errorMessage: f.message));
    }
  }

  Future<void> refresh() => load();

  Future<void> setFilter(SubRequestStatus filter) async {
    if (filter == state.filter) return;
    emit(state.copyWith(
      filter: filter,
      requests: const [],
      status: ReqStatus.loading,
    ));
    await load();
  }

  Future<bool> approve(SubscriptionRequest r) => _act(r, approving: true);

  Future<bool> reject(SubscriptionRequest r, {String? note}) =>
      _act(r, approving: false, note: note);

  Future<bool> _act(SubscriptionRequest r,
      {required bool approving, String? note}) async {
    if (state.actingOnId != null) return false;
    emit(state.copyWith(actingOnId: r.id));
    final result = approving
        ? await _repository.approveRequest(r.id)
        : await _repository.rejectRequest(r.id, note: note);
    switch (result) {
      case Success():
        // Only the Pending tab lists actionable rows, so drop it after acting.
        final remaining =
            state.requests.where((x) => x.id != r.id).toList();
        emit(state.copyWith(
          requests: remaining,
          status: remaining.isEmpty ? ReqStatus.empty : ReqStatus.loaded,
          clearActingOn: true,
        ));
        return true;
      case Err(failure: final f):
        emit(state.copyWith(errorMessage: f.message, clearActingOn: true));
        return false;
    }
  }
}
