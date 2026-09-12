import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/business.dart';

abstract class BusinessDirectoryDataSource {
  Future<List<Business>> search({
    String? query,
    int? tagId,
    String? product,
    String? city,
    String? companyType,
  });
  Future<void> boost(int id);
}

class BusinessDirectoryDataSourceImpl implements BusinessDirectoryDataSource {
  BusinessDirectoryDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<Business>> search({
    String? query,
    int? tagId,
    String? product,
    String? city,
    String? companyType,
  }) async {
    final q = <String, dynamic>{};
    if ((query ?? '').isNotEmpty) q['search'] = query;
    if (tagId != null) q['tag_id'] = tagId;
    if ((product ?? '').isNotEmpty) q['product'] = product;
    if ((city ?? '').isNotEmpty) q['city'] = city;
    if ((companyType ?? '').isNotEmpty) q['company_type'] = companyType;
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.businesses,
      query: q.isEmpty ? null : q,
    );
    return ApiEnvelope.list(res.data, Business.fromJson).items;
  }

  @override
  Future<void> boost(int id) async {
    await _client.post<dynamic>(ApiEndpoints.businessBoost(id));
  }
}
