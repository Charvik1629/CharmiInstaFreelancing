import '../../../core/network/base_repository.dart';
import '../../../core/utils/result.dart';
import '../data/broadcasts_remote_data_source.dart';
import 'broadcast_detail.dart';

abstract class BroadcastsRepository {
  Future<Result<BroadcastDetail>> create({required String name, required List<int> userIds});
  Future<Result<BroadcastDetail>> getDetail(int id);
}

class BroadcastsRepositoryImpl with BaseRepository implements BroadcastsRepository {
  BroadcastsRepositoryImpl(this._remote);

  final BroadcastsRemoteDataSource _remote;

  @override
  Future<Result<BroadcastDetail>> create({required String name, required List<int> userIds}) =>
      guard(() => _remote.create(name: name, userIds: userIds));

  @override
  Future<Result<BroadcastDetail>> getDetail(int id) =>
      guard(() => _remote.getDetail(id));
}
