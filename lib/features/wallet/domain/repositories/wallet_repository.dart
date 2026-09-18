import '../../../../core/network/api_response.dart';
import '../../../../core/utils/result.dart';
import '../entities/checkout_order.dart';
import '../entities/wallet.dart';
import '../entities/wallet_transaction.dart';

abstract class WalletRepository {
  Future<Result<Wallet>> getWallet();
  Future<Result<List<CreditPackage>>> getPackages();
  Future<Result<PaginatedResponse<WalletTransaction>>> getTransactions({int page});
  Future<Result<int>> demoTopup();

  /// POST /wallet/checkout — create a Razorpay order for [creditPackageId].
  Future<Result<CheckoutOrder>> checkout(int creditPackageId);

  /// POST /wallet/verify — confirm payment; returns the new credit balance.
  Future<Result<int>> verify({
    required int paymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  });

  /// POST /wallet/payments/{id}/outcome — report a cancel/failure.
  Future<Result<void>> reportOutcome({required int paymentId, required String status});

  /// POST /wallet/iap/verify — validate a store receipt; returns new balance.
  /// [platform] is `apple` or `google`; send [receiptData] for Apple or
  /// [purchaseToken] for Google.
  Future<Result<int>> verifyIap({
    required String platform,
    required String productId,
    String? receiptData,
    String? purchaseToken,
    String? transactionId,
  });
}
