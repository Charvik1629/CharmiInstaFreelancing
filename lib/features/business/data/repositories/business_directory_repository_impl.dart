import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/business.dart';
import '../../domain/repositories/business_directory_repository.dart';
import '../datasources/business_directory_data_source.dart';

class BusinessDirectoryRepositoryImpl
    with BaseRepository
    implements BusinessDirectoryRepository {
  BusinessDirectoryRepositoryImpl(this._remote);

  final BusinessDirectoryDataSource _remote;

  @override
  Future<Result<List<Business>>> search({
    String? query,
    int? tagId,
    String? product,
    String? city,
    String? companyType,
  }) =>
      guard(() => _remote.search(
            query: query,
            tagId: tagId,
            product: product,
            city: city,
            companyType: companyType,
          ));

  @override
  Future<Result<void>> boost(int id) => guard(() => _remote.boost(id));
}
