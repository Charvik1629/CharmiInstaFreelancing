import '../../../../core/network/api_response.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/checkout_order.dart';
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

  @override
  Future<Result<CheckoutOrder>> checkout(int creditPackageId) =>
      guard(() => _remote.checkout(creditPackageId));

  @override
  Future<Result<int>> verify({
    required int paymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) =>
      guard(() => _remote.verify(
            paymentId: paymentId,
            razorpayOrderId: razorpayOrderId,
            razorpayPaymentId: razorpayPaymentId,
            razorpaySignature: razorpaySignature,
          ));

  @override
  Future<Result<void>> reportOutcome({
    required int paymentId,
    required String status,
  }) =>
      guard(() => _remote.reportOutcome(paymentId: paymentId, status: status));

  @override
  Future<Result<int>> verifyIap({
    required String platform,
    required String productId,
    String? receiptData,
    String? purchaseToken,
    String? transactionId,
  }) =>
      guard(() => _remote.verifyIap(
            platform: platform,
            productId: productId,
            receiptData: receiptData,
            purchaseToken: purchaseToken,
            transactionId: transactionId,
          ));
}
