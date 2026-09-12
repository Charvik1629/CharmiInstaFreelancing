import '../../../../core/utils/result.dart';
import '../entities/business.dart';

abstract class BusinessDirectoryRepository {
  Future<Result<List<Business>>> search({
    String? query,
    int? tagId,
    String? product,
    String? city,
    String? companyType,
  });
  Future<Result<void>> boost(int id);
}
