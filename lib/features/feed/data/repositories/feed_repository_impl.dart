import '../../../../core/models/load.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/new_post.dart';
import '../../domain/repositories/feed_repository.dart';
import '../datasources/feed_remote_data_source.dart';

class FeedRepositoryImpl with BaseRepository implements FeedRepository {
  FeedRepositoryImpl(this._remote);

  final FeedRemoteDataSource _remote;

  @override
  Future<Result<PaginatedResponse<Load>>> getLoads({
    int page = 1,
    String? postTypeSlug,
  }) =>
      guard(() => _remote.getLoads(page: page, postTypeSlug: postTypeSlug));

  @override
  Future<Result<Load>> createLoad(NewPost post) =>
      guard(() => _remote.createLoad(post));

  @override
  Future<Result<Load>> updateLoad(int id, NewPost post) =>
      guard(() => _remote.updateLoad(id, post));

  @override
  Future<Result<int?>> requestLoad(int id) => guard(() => _remote.requestLoad(id));

  @override
  Future<Result<void>> reportLoad(int id, String reason) =>
      guard(() => _remote.reportLoad(id, reason));

  @override
  Future<Result<void>> askQuestion(int id, String body) =>
      guard(() => _remote.askQuestion(id, body));

  @override
  Future<Result<void>> deleteLoad(int id) => guard(() => _remote.deleteLoad(id));

  @override
  Future<Result<Load>> boostLoad(int id) => guard(() => _remote.boostLoad(id));

  @override
  Future<Result<Load>> markSold(int id) => guard(() => _remote.markSold(id));
}
