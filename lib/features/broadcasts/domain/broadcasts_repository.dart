import '../../../core/network/base_repository.dart';
import '../../../core/utils/result.dart';
import '../data/broadcasts_remote_data_source.dart';
import 'broadcast_detail.dart';
import 'broadcast_list_result.dart';

abstract class BroadcastsRepository {
  Future<Result<BroadcastListResult>> list({String? q});
  Future<Result<BroadcastDetail>> create({
    required String name,
    String? description,
    List<int> userIds,
  });
  Future<Result<BroadcastDetail>> getDetail(int id);
  Future<Result<BroadcastDetail>> update(int id,
      {String? name, String? description, List<int>? userIds});
  Future<Result<void>> delete(int id);
}

class BroadcastsRepositoryImpl with BaseRepository implements BroadcastsRepository {
  BroadcastsRepositoryImpl(this._remote);

  final BroadcastsRemoteDataSource _remote;

  @override
  Future<Result<BroadcastListResult>> list({String? q}) =>
      guard(() => _remote.list(q: q));

  @override
  Future<Result<BroadcastDetail>> create({
    required String name,
    String? description,
    List<int> userIds = const [],
  }) =>
      guard(() => _remote.create(
            name: name,
            description: description,
            userIds: userIds,
          ));

  @override
  Future<Result<BroadcastDetail>> getDetail(int id) =>
      guard(() => _remote.getDetail(id));

  @override
  Future<Result<BroadcastDetail>> update(int id,
          {String? name, String? description, List<int>? userIds}) =>
      guard(() => _remote.update(id,
          name: name, description: description, userIds: userIds));

  @override
  Future<Result<void>> delete(int id) => guard(() => _remote.delete(id));
}
