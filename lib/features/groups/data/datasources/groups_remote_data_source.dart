import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_join_request.dart';

abstract class GroupsRemoteDataSource {
  Future<List<Group>> getRecommended();
  Future<List<Group>> getMyGroups();
  Future<Group> getGroup(int id);
  Future<List<GroupMember>> getMembers(int id);

  /// POST /groups/{id}/join-requests — request to join a (private) group.
  Future<void> requestJoin(int id);

  /// DELETE /groups/{id}/join-requests/me — cancel my pending request.
  Future<void> cancelJoinRequest(int id);

  /// POST /groups/{id}/leave.
  Future<void> leave(int id);

  // Admin management.
  /// GET /admin/groups/join-request-summary → total pending across all groups.
  Future<int> getJoinRequestSummaryTotal();
  Future<List<GroupJoinRequest>> getJoinRequests(int id);
  Future<void> approveJoinRequest(int id, int requestId);
  Future<void> declineJoinRequest(int id, int requestId);
  Future<void> removeMember(int id, int userId);
}

class GroupsRemoteDataSourceImpl implements GroupsRemoteDataSource {
  GroupsRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  Future<List<Group>> _list(String path) async {
    final res = await _client.get<Map<String, dynamic>>(path);
    final raw = res.data?['data'];
    final out = <Group>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) out.add(Group.fromJson(e));
      }
    }
    return out;
  }

  @override
  Future<List<Group>> getRecommended() => _list(ApiEndpoints.groupsRecommended);

  @override
  Future<List<Group>> getMyGroups() => _list(ApiEndpoints.groups);

  @override
  Future<Group> getGroup(int id) async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.group(id));
    return ApiEnvelope.object(res.data, Group.fromJson);
  }

  @override
  Future<List<GroupMember>> getMembers(int id) async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.groupMembers(id));
    final raw = res.data?['data'];
    final out = <GroupMember>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) out.add(GroupMember.fromJson(e));
      }
    }
    return out;
  }

  @override
  Future<void> requestJoin(int id) =>
      _client.post<dynamic>(ApiEndpoints.groupJoinRequests(id));

  @override
  Future<void> cancelJoinRequest(int id) =>
      _client.delete<dynamic>(ApiEndpoints.groupJoinRequestMe(id));

  @override
  Future<void> leave(int id) =>
      _client.post<dynamic>(ApiEndpoints.groupLeave(id));

  @override
  Future<int> getJoinRequestSummaryTotal() async {
    final res = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.adminGroupsJoinRequestSummary);
    final data = res.data?['data'];
    if (data is Map && data['total'] is num) {
      return (data['total'] as num).toInt();
    }
    return 0;
  }

  @override
  Future<List<GroupJoinRequest>> getJoinRequests(int id) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.groupJoinRequests(id),
      query: {'status': 'pending'},
    );
    return ApiEnvelope.list(res.data, GroupJoinRequest.fromJson).items;
  }

  @override
  Future<void> approveJoinRequest(int id, int requestId) =>
      _client.post<dynamic>(ApiEndpoints.groupJoinRequestApprove(id, requestId));

  @override
  Future<void> declineJoinRequest(int id, int requestId) =>
      _client.post<dynamic>(ApiEndpoints.groupJoinRequestDecline(id, requestId));

  @override
  Future<void> removeMember(int id, int userId) =>
      _client.delete<dynamic>(ApiEndpoints.groupMember(id, userId));
}
