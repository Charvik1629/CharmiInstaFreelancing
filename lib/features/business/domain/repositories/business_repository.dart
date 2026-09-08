import '../../../../core/utils/result.dart';
import '../entities/business_post.dart';

abstract class BusinessRepository {
  Future<Result<List<BusinessPost>>> getPosts({int page});
  Future<Result<void>> reportPost(int id, String reason);
}
