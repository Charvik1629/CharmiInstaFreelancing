import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_join_request.dart';
import '../../domain/repositories/groups_repository.dart';
import '../datasources/groups_remote_data_source.dart';

class GroupsRepositoryImpl with BaseRepository implements GroupsRepository {
  GroupsRepositoryImpl(this._remote);

  final GroupsRemoteDataSource _remote;

  @override
  Future<Result<List<Group>>> getRecommended() =>
      guard(() => _remote.getRecommended());

  @override
  Future<Result<List<Group>>> getMyGroups() => guard(() => _remote.getMyGroups());

  @override
  Future<Result<Group>> getGroup(int id) => guard(() => _remote.getGroup(id));

  @override
  Future<Result<List<GroupMember>>> getMembers(int id) =>
      guard(() => _remote.getMembers(id));

  @override
  Future<Result<void>> requestJoin(int id) =>
      guard(() => _remote.requestJoin(id));

  @override
  Future<Result<void>> cancelJoinRequest(int id) =>
      guard(() => _remote.cancelJoinRequest(id));

  @override
  Future<Result<void>> leave(int id) => guard(() => _remote.leave(id));

  @override
  Future<Result<int>> getJoinRequestSummaryTotal() =>
      guard(_remote.getJoinRequestSummaryTotal);

  @override
  Future<Result<List<GroupJoinRequest>>> getJoinRequests(int id) =>
      guard(() => _remote.getJoinRequests(id));

  @override
  Future<Result<void>> approveJoinRequest(int id, int requestId) =>
      guard(() => _remote.approveJoinRequest(id, requestId));

  @override
  Future<Result<void>> declineJoinRequest(int id, int requestId) =>
      guard(() => _remote.declineJoinRequest(id, requestId));

  @override
  Future<Result<void>> removeMember(int id, int userId) =>
      guard(() => _remote.removeMember(id, userId));
}
