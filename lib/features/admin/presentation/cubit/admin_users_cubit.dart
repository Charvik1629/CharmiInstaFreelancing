import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/user_approval.dart';
import '../../domain/repositories/admin_repository.dart';

part 'admin_users_state.dart';

/// Drives the super-admin "User approval" queue: Pending / Approved / Rejected
/// tabs, with per-user Approve / Reject actions. A pending account cannot log in
/// until it is approved here (login returns 403 otherwise).
class AdminUsersCubit extends Cubit<AdminUsersState> {
  AdminUsersCubit(this._repository) : super(const AdminUsersState());

  final AdminRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: UsersStatus.loading));
    final result = await _repository.getUsers(status: state.filter, page: 1);
    switch (result) {
      case Success(value: final res):
        emit(state.copyWith(
          status: res.items.isEmpty ? UsersStatus.empty : UsersStatus.loaded,
          users: res.items,
        ));
      case Err(failure: final f):
        emit(state.copyWith(status: UsersStatus.error, errorMessage: f.message));
    }
  }

  Future<void> refresh() => load();

  Future<void> setFilter(UserApprovalStatus filter) async {
    if (filter == state.filter) return;
    emit(state.copyWith(
      filter: filter,
      users: const [],
      status: UsersStatus.loading,
    ));
    await load();
  }

  /// Approves an account. On success it drops from the current list (unless the
  /// Approved tab is being viewed).
  Future<bool> approve(User user) => _act(user, approving: true);

  /// Rejects an account. On success it drops from the current list (unless the
  /// Rejected tab is being viewed).
  Future<bool> reject(User user) => _act(user, approving: false);

  Future<bool> _act(User user, {required bool approving}) async {
    // Guard against double taps on an in-flight row.
    if (state.actingOnId != null) return false;
    emit(state.copyWith(actingOnId: user.id));
    final result = approving
        ? await _repository.approveUser(user.id)
        : await _repository.rejectUser(user.id);
    switch (result) {
      case Success():
        final stayInList =
            (approving && state.filter == UserApprovalStatus.approved) ||
                (!approving && state.filter == UserApprovalStatus.rejected);
        final users = stayInList
            ? state.users
            : state.users.where((u) => u.id != user.id).toList();
        emit(state.copyWith(
          users: users,
          status: users.isEmpty ? UsersStatus.empty : UsersStatus.loaded,
          clearActingOn: true,
        ));
        return true;
      case Err(failure: final f):
        emit(state.copyWith(errorMessage: f.message, clearActingOn: true));
        return false;
    }
  }
}
