import '../../../../core/network/api_response.dart';
import '../../../../core/utils/result.dart';
import '../../data/datasources/offers_remote_data_source.dart';
import '../entities/offer.dart';

abstract class OffersRepository {
  Future<Result<PaginatedResponse<Offer>>> getOffers({
    required OfferTag tag,
    int page = 1,
  });

  Future<Result<Offer>> makeOffer({
    required int loadId,
    required String body,
    required num price,
  });
}
