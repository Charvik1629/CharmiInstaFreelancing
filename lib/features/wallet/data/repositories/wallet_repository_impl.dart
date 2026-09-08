import '../../../../core/network/api_response.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_remote_data_source.dart';

class WalletRepositoryImpl with BaseRepository implements WalletRepository {
  WalletRepositoryImpl(this._remote);

  final WalletRemoteDataSource _remote;

  @override
  Future<Result<Wallet>> getWallet() => guard(() => _remote.getWallet());

  @override
  Future<Result<List<CreditPackage>>> getPackages() =>
      guard(() => _remote.getPackages());

  @override
  Future<Result<PaginatedResponse<WalletTransaction>>> getTransactions({int page = 1}) =>
      guard(() => _remote.getTransactions(page: page));

  @override
  Future<Result<int>> demoTopup() => guard(() => _remote.demoTopup());
}
