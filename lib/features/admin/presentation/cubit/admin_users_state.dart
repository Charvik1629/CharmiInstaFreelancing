part of 'admin_users_cubit.dart';

enum UsersStatus { initial, loading, loaded, empty, error }

class AdminUsersState extends Equatable {
  const AdminUsersState({
    this.status = UsersStatus.initial,
    this.filter = UserApprovalStatus.pending,
    this.users = const [],
    this.actingOnId,
    this.errorMessage,
  });

  final UsersStatus status;
  final UserApprovalStatus filter;
  final List<User> users;

  /// Id of the row whose approve/reject is in flight (disables its buttons).
  final int? actingOnId;
  final String? errorMessage;

  AdminUsersState copyWith({
    UsersStatus? status,
    UserApprovalStatus? filter,
    List<User>? users,
    int? actingOnId,
    bool clearActingOn = false,
    String? errorMessage,
  }) {
    return AdminUsersState(
      status: status ?? this.status,
      filter: filter ?? this.filter,
      users: users ?? this.users,
      actingOnId: clearActingOn ? null : (actingOnId ?? this.actingOnId),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, filter, users, actingOnId, errorMessage];
}
