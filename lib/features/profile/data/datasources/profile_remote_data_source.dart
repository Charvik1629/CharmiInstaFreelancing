import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/models/user.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/profile_update.dart';

/// Raw profile endpoint calls. Throws [AppException] on failure (mapped by
/// [ApiClient]); the repository converts to typed failures.
abstract class ProfileRemoteDataSource {
  /// GET /profile — the authenticated user's full profile.
  Future<User> getProfile();

  /// PUT /profile — updates the profile. Uses multipart when an avatar image is
  /// attached, otherwise a JSON body. Returns the updated [User].
  Future<User> updateProfile(ProfileUpdate update);

  /// GET /users/{id} — another user's public profile.
  Future<User> getUser(int id);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<User> getProfile() async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.profile);
    return ApiEnvelope.object(res.data, User.fromJson);
  }

  @override
  Future<User> updateProfile(ProfileUpdate update) async {
    final fields = <String, dynamic>{
      if (update.name != null) 'name': update.name,
      if (update.bio != null) 'bio': update.bio,
      if (update.phone != null) 'phone': update.phone,
      // Business details (BACKEND_REQUIREMENTS B1) — sent so they persist once
      // the backend accepts them; ignored server-side until then.
      if (update.businessName != null) 'business_name': update.businessName,
      if (update.companyType != null) 'company_type': update.companyType,
      if (update.msmeNumber != null) 'msme_number': update.msmeNumber,
      if (update.website != null) 'website': update.website,
      if (update.description != null) 'description': update.description,
      if (update.association != null) 'association': update.association,
      if (update.address != null) 'address': update.address,
      if (update.city != null) 'city': update.city,
      if (update.state != null) 'state': update.state,
      if (update.pincode != null) 'pincode': update.pincode,
      if (update.products != null && update.products!.isNotEmpty)
        'products': update.products,
      if (update.tagIds != null && update.tagIds!.isNotEmpty)
        'tag_ids': update.tagIds,
      if (update.socialLinks != null && update.socialLinks!.isNotEmpty)
        for (final e in update.socialLinks!.entries)
          'social_links[${e.key}]': e.value,
    };

    final Object body;
    if (update.hasAvatar || update.hasLogo) {
      body = FormData.fromMap({
        ...fields,
        if (update.hasAvatar)
          'avatar': await MultipartFile.fromFile(
            update.avatarPath!,
            filename: update.avatarPath!.split('/').last,
          ),
        if (update.hasLogo)
          'logo': await MultipartFile.fromFile(
            update.logoPath!,
            filename: update.logoPath!.split('/').last,
          ),
      });
    } else {
      body = fields;
    }

    // The API accepts PUT or POST; POST is used so multipart bodies work on
    // servers/proxies that mishandle multipart over PUT.
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.profile,
      data: body,
    );
    return ApiEnvelope.object(res.data, User.fromJson);
  }

  @override
  Future<User> getUser(int id) async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.user(id));
    return ApiEnvelope.object(res.data, User.fromJson);
  }
}
