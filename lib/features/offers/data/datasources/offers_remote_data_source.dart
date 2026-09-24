import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/offer.dart';

/// Which side of the offer inbox to show (design: All / Received / Sent).
enum OfferTag { all, received, sent }

abstract class OffersRemoteDataSource {
  /// GET /offers?tag=received|sent — paginated.
  Future<PaginatedResponse<Offer>> getOffers({
    required OfferTag tag,
    int page = 1,
  });

  /// POST /loads/{id}/offers — make an offer (body + price). Returns the
  /// created [Offer] (which carries the opened conversationId).
  Future<Offer> makeOffer({
    required int loadId,
    required String body,
    required num price,
  });
}

class OffersRemoteDataSourceImpl implements OffersRemoteDataSource {
  OffersRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<PaginatedResponse<Offer>> getOffers({
    required OfferTag tag,
    int page = 1,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.offers,
      query: {
        // "All" fetches both sides — omit the filter so the API returns
        // received + sent together.
        if (tag != OfferTag.all) 'tag': tag.name,
        'page': page,
        'per_page': AppConstants.defaultPageSize,
      },
    );
    return ApiEnvelope.list(res.data, Offer.fromJson);
  }

  @override
  Future<Offer> makeOffer({
    required int loadId,
    required String body,
    required num price,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.loadOffers(loadId),
      data: {'body': body, 'price': price},
    );
    return ApiEnvelope.object(res.data, Offer.fromJson);
  }
}
