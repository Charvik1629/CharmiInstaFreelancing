import '../../../../core/models/user.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/search_remote_data_source.dart';

class SearchRepositoryImpl with BaseRepository implements SearchRepository {
  SearchRepositoryImpl(this._remote);

  final SearchRemoteDataSource _remote;

  @override
  Future<Result<List<User>>> searchUsers(String query) =>
      guard(() => _remote.searchUsers(query));
}
