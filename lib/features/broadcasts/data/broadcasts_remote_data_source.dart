import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/json_extensions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../chat/domain/entities/broadcast_quota.dart';
import '../domain/broadcast_detail.dart';
import '../domain/broadcast_list_result.dart';

abstract class BroadcastsRemoteDataSource {
  /// GET /broadcasts — broadcast groups the caller owns or belongs to, with an
  /// optional name search ([q]). Carries `meta.broadcast_list_quota` when present.
  Future<BroadcastListResult> list({String? q});

  /// POST /broadcasts — create a broadcast group.
  Future<BroadcastDetail> create({
    required String name,
    String? description,
    List<int> userIds = const [],
  });

  /// GET /broadcasts/{id} — a broadcast group with its recipients.
  Future<BroadcastDetail> getDetail(int id);

  /// PUT /broadcasts/{id} — rename and/or change recipients.
  Future<BroadcastDetail> update(int id,
      {String? name, String? description, List<int>? userIds});

  /// DELETE /broadcasts/{id} — delete a broadcast group.
  Future<void> delete(int id);
}

class BroadcastsRemoteDataSourceImpl implements BroadcastsRemoteDataSource {
  BroadcastsRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<BroadcastListResult> list({String? q}) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.broadcasts,
      query: {
        'per_page': AppConstants.defaultPageSize,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final page = ApiEnvelope.list(res.data, BroadcastDetail.fromJson);
    final rawQuota = res.data?.asMap('meta')?.asMap('broadcast_list_quota');
    return BroadcastListResult(
      items: page.items,
      meta: page.meta,
      quota: rawQuota == null ? null : BroadcastQuota.fromJson(rawQuota),
    );
  }

  @override
  Future<BroadcastDetail> create({
    required String name,
    String? description,
    List<int> userIds = const [],
  }) async {
    // The live server validates `name` ("The name field is required."); the docs
    // also mention `title`. Send BOTH so whichever the backend expects is
    // satisfied. `user_ids` attaches initial members when supported.
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.broadcasts,
      data: {
        'name': name,
        'title': name,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (userIds.isNotEmpty) 'user_ids': userIds,
      },
    );
    return ApiEnvelope.object(res.data, BroadcastDetail.fromJson);
  }

  @override
  Future<BroadcastDetail> getDetail(int id) async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.broadcast(id));
    return ApiEnvelope.object(res.data, BroadcastDetail.fromJson);
  }

  @override
  Future<BroadcastDetail> update(int id,
      {String? name, String? description, List<int>? userIds}) async {
    final body = <String, dynamic>{};
    if (name != null) {
      body['name'] = name;
      body['title'] = name;
    }
    if (description != null) body['description'] = description;
    if (userIds != null) body['user_ids'] = userIds;
    final res = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.broadcast(id),
      data: body,
    );
    return ApiEnvelope.object(res.data, BroadcastDetail.fromJson);
  }

  @override
  Future<void> delete(int id) async {
    await _client.delete<dynamic>(ApiEndpoints.broadcast(id));
  }
}
