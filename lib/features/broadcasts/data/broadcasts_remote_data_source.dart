import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/broadcast_detail.dart';

abstract class BroadcastsRemoteDataSource {
  /// POST /broadcasts — create a broadcast list (debits credits).
  Future<BroadcastDetail> create({required String name, required List<int> userIds});

  /// GET /broadcasts/{id} — a broadcast list with recipients.
  Future<BroadcastDetail> getDetail(int id);
}

class BroadcastsRemoteDataSourceImpl implements BroadcastsRemoteDataSource {
  BroadcastsRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<BroadcastDetail> create({required String name, required List<int> userIds}) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.broadcasts,
      data: {'name': name, 'user_ids': userIds},
    );
    return ApiEnvelope.object(res.data, BroadcastDetail.fromJson);
  }

  @override
  Future<BroadcastDetail> getDetail(int id) async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.broadcast(id));
    return ApiEnvelope.object(res.data, BroadcastDetail.fromJson);
  }
}
