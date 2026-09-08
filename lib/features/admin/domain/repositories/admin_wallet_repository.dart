import '../../../../core/utils/result.dart';
import '../entities/wallet_package.dart';
import '../entities/wallet_settings.dart';

abstract class AdminWalletRepository {
  Future<Result<List<WalletPackage>>> getPackages();
  Future<Result<WalletPackage>> createPackage({
    required String name,
    required int credits,
    required int amountPaise,
    required bool isActive,
    required int sortOrder,
  });
  Future<Result<WalletPackage>> updatePackage({
    required int id,
    required String name,
    required int credits,
    required int amountPaise,
    required bool isActive,
    required int sortOrder,
  });
  Future<Result<void>> deletePackage(int id);

  Future<Result<WalletSettings>> getSettings();
  Future<Result<WalletSettings>> updateSettings(Map<String, dynamic> changes);

  Future<Result<int>> adjustUser({
    required int userId,
    required int amount,
    required String direction,
    String? note,
  });
}
