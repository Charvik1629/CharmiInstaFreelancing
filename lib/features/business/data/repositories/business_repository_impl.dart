import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/business_post.dart';
import '../../domain/repositories/business_repository.dart';
import '../datasources/business_remote_data_source.dart';

class BusinessRepositoryImpl with BaseRepository implements BusinessRepository {
  BusinessRepositoryImpl(this._remote);

  final BusinessRemoteDataSource _remote;

  @override
  Future<Result<List<BusinessPost>>> getPosts({int page = 1}) =>
      guard(() => _remote.getPosts(page: page));

  @override
  Future<Result<void>> reportPost(int id, String reason) =>
      guard(() => _remote.reportPost(id, reason));
}
