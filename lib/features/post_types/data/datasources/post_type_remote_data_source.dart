import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/models/post_type.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';

/// Talks to the post-types endpoint and returns parsed models. Throws
/// [AppException] on transport/HTTP errors (mapped by [ApiClient]); the
/// repository turns those into failures.
abstract class PostTypeRemoteDataSource {
  Future<List<PostType>> getPostTypes();
}

class PostTypeRemoteDataSourceImpl implements PostTypeRemoteDataSource {
  PostTypeRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<PostType>> getPostTypes() async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.postTypes);
    return ApiEnvelope.list(res.data, PostType.fromJson).items;
  }
}
