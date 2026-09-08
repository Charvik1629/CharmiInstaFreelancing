import '../../../../core/network/api_response.dart';
import '../../../../core/utils/result.dart';
import '../entities/wallet.dart';
import '../entities/wallet_transaction.dart';

abstract class WalletRepository {
  Future<Result<Wallet>> getWallet();
  Future<Result<List<CreditPackage>>> getPackages();
  Future<Result<PaginatedResponse<WalletTransaction>>> getTransactions({int page});
  Future<Result<int>> demoTopup();
}
