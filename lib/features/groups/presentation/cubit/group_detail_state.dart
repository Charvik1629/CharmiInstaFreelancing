part of 'group_detail_cubit.dart';

enum DetailStatus { initial, loading, loaded, error }

class GroupDetailState extends Equatable {
  const GroupDetailState({
    this.status = DetailStatus.initial,
    this.group,
    this.members = const [],
    this.hiddenMemberCount = 0,
    this.joinRequests = const [],
    this.isManager = false,
    this.actingOnId,
    this.errorMessage,
  });

  final DetailStatus status;
  final Group? group;
  final List<GroupMember> members;

  /// Members filtered out of [members] (hidden system admins). Used to adjust
  /// the server-provided header count so it matches the visible list.
  final int hiddenMemberCount;
  final List<GroupJoinRequest> joinRequests;

  /// Whether the viewer can manage the group (admin role).
  final bool isManager;

  /// Join-request id whose approve/decline is in flight.
  final int? actingOnId;
  final String? errorMessage;

  GroupDetailState copyWith({
    DetailStatus? status,
    Group? group,
    List<GroupMember>? members,
    int? hiddenMemberCount,
    List<GroupJoinRequest>? joinRequests,
    bool? isManager,
    int? actingOnId,
    bool clearActingOn = false,
    String? errorMessage,
  }) {
    return GroupDetailState(
      status: status ?? this.status,
      group: group ?? this.group,
      members: members ?? this.members,
      hiddenMemberCount: hiddenMemberCount ?? this.hiddenMemberCount,
      joinRequests: joinRequests ?? this.joinRequests,
      isManager: isManager ?? this.isManager,
      actingOnId: clearActingOn ? null : (actingOnId ?? this.actingOnId),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        group,
        members,
        hiddenMemberCount,
        joinRequests,
        isManager,
        actingOnId,
        errorMessage,
      ];
}
