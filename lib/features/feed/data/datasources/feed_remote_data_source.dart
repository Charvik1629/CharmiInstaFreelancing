import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/load.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/new_post.dart';

/// Raw feed endpoint calls. Throws [AppException] on failure (mapped by
/// [ApiClient]); the repository converts to typed failures.
abstract class FeedRemoteDataSource {
  Future<PaginatedResponse<Load>> getLoads({
    int page = 1,
    int perPage = AppConstants.defaultPageSize,
    String? postTypeSlug, // buy | sell | business ; null = all
  });

  /// Creates a new load (post). Sends multipart/form-data when an image is
  /// attached, otherwise a plain JSON body. Returns the created [Load].
  Future<Load> createLoad(NewPost post);

  /// Opens (or reuses) a chat with the load's author. Returns conversationId.
  Future<int?> requestLoad(int id);

  /// Reports a load with a free-text reason.
  Future<void> reportLoad(int id, String reason);

  /// Asks a question on a load (POST /loads/{id}/questions).
  Future<void> askQuestion(int id, String body);

  /// Soft-deletes a load the viewer owns.
  Future<void> deleteLoad(int id);

  /// POST /loads/{id}/boost — owner boosts an active post (debits credits).
  Future<Load> boostLoad(int id);
}

class FeedRemoteDataSourceImpl implements FeedRemoteDataSource {
  FeedRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<PaginatedResponse<Load>> getLoads({
    int page = 1,
    int perPage = AppConstants.defaultPageSize,
    String? postTypeSlug,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.loads,
      query: {
        'page': page,
        'per_page': perPage,
        'post_type': ?postTypeSlug,
      },
    );
    return ApiEnvelope.list(res.data, Load.fromJson);
  }

  @override
  Future<Load> createLoad(NewPost post) async {
    final fields = <String, dynamic>{
      'title': post.title,
      if (post.body != null && post.body!.isNotEmpty) 'body': post.body,
      if (post.postTypeId != null) 'post_type_id': post.postTypeId,
    };

    // With an image we must use multipart; text-only posts send JSON so the
    // server sees the same shape the rest of the API uses. Tags go as `tag_ids`
    // (JSON array) or repeated `tag_ids[]` fields (multipart).
    final Object body;
    if (post.hasImage) {
      body = FormData.fromMap({
        ...fields,
        if (post.tagIds.isNotEmpty) 'tag_ids[]': post.tagIds,
        'media': await MultipartFile.fromFile(
          post.imagePath!,
          filename: post.imagePath!.split('/').last,
        ),
      });
    } else {
      body = {
        ...fields,
        if (post.tagIds.isNotEmpty) 'tag_ids': post.tagIds,
      };
    }

    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.loads,
      data: body,
    );
    return ApiEnvelope.object(res.data, Load.fromJson);
  }

  @override
  Future<int?> requestLoad(int id) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.loadRequest(id),
    );
    final data = res.data?['data'];
    return data is Map<String, dynamic>
        ? (data['conversation_id'] as num?)?.toInt()
        : null;
  }

  @override
  Future<void> reportLoad(int id, String reason) async {
    await _client.post<dynamic>(
      ApiEndpoints.loadReports(id),
      data: {'body': reason},
    );
  }

  @override
  Future<void> askQuestion(int id, String body) async {
    await _client.post<dynamic>(
      ApiEndpoints.loadQuestions(id),
      data: {'body': body},
    );
  }

  @override
  Future<void> deleteLoad(int id) async {
    await _client.delete<dynamic>(ApiEndpoints.load(id));
  }

  @override
  Future<Load> boostLoad(int id) async {
    final res =
        await _client.post<Map<String, dynamic>>(ApiEndpoints.loadBoost(id));
    return ApiEnvelope.object(res.data, Load.fromJson);
  }
}
