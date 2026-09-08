part of 'groups_list_cubit.dart';

enum GroupsStatus { initial, loading, loaded, error }

class GroupsListState extends Equatable {
  const GroupsListState({
    this.status = GroupsStatus.initial,
    this.myGroups = const [],
    this.recommended = const [],
    this.pendingJoinTotal = 0,
    this.errorMessage,
  });

  final GroupsStatus status;
  final List<Group> myGroups;
  final List<Group> recommended;

  /// Admin-only: total pending join requests across all groups.
  final int pendingJoinTotal;
  final String? errorMessage;

  bool get isEmpty => myGroups.isEmpty && recommended.isEmpty;

  GroupsListState copyWith({
    GroupsStatus? status,
    List<Group>? myGroups,
    List<Group>? recommended,
    int? pendingJoinTotal,
    String? errorMessage,
  }) {
    return GroupsListState(
      status: status ?? this.status,
      myGroups: myGroups ?? this.myGroups,
      recommended: recommended ?? this.recommended,
      pendingJoinTotal: pendingJoinTotal ?? this.pendingJoinTotal,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, myGroups, recommended, pendingJoinTotal, errorMessage];
}
