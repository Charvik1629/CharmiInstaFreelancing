import '../../../../core/models/user.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/profile_update.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl with BaseRepository implements ProfileRepository {
  ProfileRepositoryImpl(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  Future<Result<User>> getProfile() => guard(() => _remote.getProfile());

  @override
  Future<Result<User>> updateProfile(ProfileUpdate update) =>
      guard(() => _remote.updateProfile(update));

  @override
  Future<Result<User>> getUser(int id) => guard(() => _remote.getUser(id));
}
