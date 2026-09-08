import '../../../../core/utils/result.dart';
import '../entities/group.dart';
import '../entities/group_join_request.dart';

abstract class GroupsRepository {
  Future<Result<List<Group>>> getRecommended();
  Future<Result<List<Group>>> getMyGroups();
  Future<Result<Group>> getGroup(int id);
  Future<Result<List<GroupMember>>> getMembers(int id);

  /// Request to join a (private) group.
  Future<Result<void>> requestJoin(int id);
  Future<Result<void>> cancelJoinRequest(int id);
  Future<Result<void>> leave(int id);

  // Admin management.
  Future<Result<int>> getJoinRequestSummaryTotal();
  Future<Result<List<GroupJoinRequest>>> getJoinRequests(int id);
  Future<Result<void>> approveJoinRequest(int id, int requestId);
  Future<Result<void>> declineJoinRequest(int id, int requestId);
  Future<Result<void>> removeMember(int id, int userId);
}
