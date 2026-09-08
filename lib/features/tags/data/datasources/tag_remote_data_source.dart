import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/tag.dart';

abstract class TagRemoteDataSource {
  /// GET /tags — active tags for the user picker (post/business tagging).
  Future<List<Tag>> getTags();

  /// GET /admin/tags — all tags (includes inactive).
  Future<List<Tag>> getAllTags();

  /// POST /admin/tags — create. Slug is derived from name when omitted.
  Future<Tag> createTag({
    required String name,
    String? slug,
    required bool isActive,
    required int sortOrder,
  });

  /// PATCH /admin/tags/{id} — update.
  Future<Tag> updateTag({
    required int id,
    required String name,
    String? slug,
    required bool isActive,
    required int sortOrder,
  });

  /// DELETE /admin/tags/{id}.
  Future<void> deleteTag(int id);
}

class TagRemoteDataSourceImpl implements TagRemoteDataSource {
  TagRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  Map<String, dynamic> _body({
    required String name,
    String? slug,
    required bool isActive,
    required int sortOrder,
  }) =>
      {
        'name': name,
        if (slug != null && slug.isNotEmpty) 'slug': slug,
        'is_active': isActive,
        'sort_order': sortOrder,
      };

  @override
  Future<List<Tag>> getTags() async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.tags);
    return ApiEnvelope.list(res.data, Tag.fromJson).items;
  }

  @override
  Future<List<Tag>> getAllTags() async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.adminTags);
    return ApiEnvelope.list(res.data, Tag.fromJson).items;
  }

  @override
  Future<Tag> createTag({
    required String name,
    String? slug,
    required bool isActive,
    required int sortOrder,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.adminTags,
      data: _body(
          name: name, slug: slug, isActive: isActive, sortOrder: sortOrder),
    );
    return ApiEnvelope.object(res.data, Tag.fromJson);
  }

  @override
  Future<Tag> updateTag({
    required int id,
    required String name,
    String? slug,
    required bool isActive,
    required int sortOrder,
  }) async {
    final res = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.adminTag(id),
      data: _body(
          name: name, slug: slug, isActive: isActive, sortOrder: sortOrder),
    );
    return ApiEnvelope.object(res.data, Tag.fromJson);
  }

  @override
  Future<void> deleteTag(int id) async {
    await _client.delete<dynamic>(ApiEndpoints.adminTag(id));
  }
}
