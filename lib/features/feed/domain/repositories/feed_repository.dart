import '../../../../core/models/load.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/utils/result.dart';
import '../entities/new_post.dart';

abstract class FeedRepository {
  Future<Result<PaginatedResponse<Load>>> getLoads({
    int page = 1,
    String? postTypeSlug,
  });

  /// Creates a post; on success returns the created [Load].
  Future<Result<Load>> createLoad(NewPost post);

  /// Updates an owned post. Returns the updated [Load].
  Future<Result<Load>> updateLoad(int id, NewPost post);

  Future<Result<int?>> requestLoad(int id);
  Future<Result<void>> reportLoad(int id, String reason);
  Future<Result<void>> askQuestion(int id, String body);
  Future<Result<void>> deleteLoad(int id);

  /// Boosts an owned post (debits credits). Returns the updated [Load].
  Future<Result<Load>> boostLoad(int id);

  /// Marks an owned post as sold/closed. Returns the updated [Load].
  Future<Result<Load>> markSold(int id);
}
