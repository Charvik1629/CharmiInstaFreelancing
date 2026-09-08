import '../../../../core/models/post_type.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/post_type_repository.dart';
import '../datasources/post_type_remote_data_source.dart';

/// Wraps the datasource call in [BaseRepository.guard] so transport/HTTP errors
/// become typed [Failure]s and a placeholder base URL short-circuits cleanly.
class PostTypeRepositoryImpl with BaseRepository implements PostTypeRepository {
  PostTypeRepositoryImpl(this._remote);

  final PostTypeRemoteDataSource _remote;

  @override
  Future<Result<List<PostType>>> getPostTypes() =>
      guard(_remote.getPostTypes);
}
