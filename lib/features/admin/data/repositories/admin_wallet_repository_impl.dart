import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/wallet_package.dart';
import '../../domain/entities/wallet_settings.dart';
import '../../domain/repositories/admin_wallet_repository.dart';
import '../datasources/admin_wallet_remote_data_source.dart';

class AdminWalletRepositoryImpl
    with BaseRepository
    implements AdminWalletRepository {
  AdminWalletRepositoryImpl(this._remote);

  final AdminWalletRemoteDataSource _remote;

  @override
  Future<Result<List<WalletPackage>>> getPackages() =>
      guard(_remote.getPackages);

  @override
  Future<Result<WalletPackage>> createPackage({
    required String name,
    required int credits,
    required int amountPaise,
    required bool isActive,
    required int sortOrder,
  }) =>
      guard(() => _remote.createPackage(
            name: name,
            credits: credits,
            amountPaise: amountPaise,
            isActive: isActive,
            sortOrder: sortOrder,
          ));

  @override
  Future<Result<WalletPackage>> updatePackage({
    required int id,
    required String name,
    required int credits,
    required int amountPaise,
    required bool isActive,
    required int sortOrder,
  }) =>
      guard(() => _remote.updatePackage(
            id: id,
            name: name,
            credits: credits,
            amountPaise: amountPaise,
            isActive: isActive,
            sortOrder: sortOrder,
          ));

  @override
  Future<Result<void>> deletePackage(int id) =>
      guard(() => _remote.deletePackage(id));

  @override
  Future<Result<WalletSettings>> getSettings() => guard(_remote.getSettings);

  @override
  Future<Result<WalletSettings>> updateSettings(Map<String, dynamic> changes) =>
      guard(() => _remote.updateSettings(changes));

  @override
  Future<Result<int>> adjustUser({
    required int userId,
    required int amount,
    required String direction,
    String? note,
  }) =>
      guard(() => _remote.adjustUser(
            userId: userId,
            amount: amount,
            direction: direction,
            note: note,
          ));
}
