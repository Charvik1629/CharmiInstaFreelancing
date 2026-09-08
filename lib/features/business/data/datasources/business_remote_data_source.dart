import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/business_post.dart';

abstract class BusinessRemoteDataSource {
  Future<List<BusinessPost>> getPosts({int page});
  Future<void> reportPost(int id, String reason);
}

class BusinessRemoteDataSourceImpl implements BusinessRemoteDataSource {
  BusinessRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<BusinessPost>> getPosts({int page = 1}) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.businessPosts,
      query: {'page': page},
    );
    return ApiEnvelope.list(res.data, BusinessPost.fromJson).items;
  }

  @override
  Future<void> reportPost(int id, String reason) async {
    await _client.post<dynamic>(
      ApiEndpoints.businessPostReport(id),
      data: {'reason': reason},
    );
  }
}
