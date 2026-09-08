import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/models/user.dart';
import '../../../../core/network/api_client.dart';

/// People search (GET /users?q=). Throws [AppException] on failure (mapped by
/// [ApiClient]); the repository converts to typed failures.
abstract class SearchRemoteDataSource {
  Future<List<User>> searchUsers(String query, {int limit = 20});
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  SearchRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<User>> searchUsers(String query, {int limit = 20}) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.users,
      query: {'q': query, 'limit': limit},
    );
    final raw = res.data?['data'];
    final out = <User>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) out.add(User.fromJson(e));
      }
    }
    return out;
  }
}
