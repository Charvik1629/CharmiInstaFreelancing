import '../../../../core/network/api_response.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/offer.dart';
import '../../domain/repositories/offers_repository.dart';
import '../datasources/offers_remote_data_source.dart';

class OffersRepositoryImpl with BaseRepository implements OffersRepository {
  OffersRepositoryImpl(this._remote);

  final OffersRemoteDataSource _remote;

  @override
  Future<Result<PaginatedResponse<Offer>>> getOffers({
    required OfferTag tag,
    int page = 1,
  }) =>
      guard(() => _remote.getOffers(tag: tag, page: page));

  @override
  Future<Result<Offer>> makeOffer({
    required int loadId,
    required String body,
    required num price,
  }) =>
      guard(() => _remote.makeOffer(loadId: loadId, body: body, price: price));
}
