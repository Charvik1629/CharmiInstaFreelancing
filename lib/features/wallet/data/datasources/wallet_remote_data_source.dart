import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/checkout_order.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_transaction.dart';

abstract class WalletRemoteDataSource {
  /// GET /wallet — balance, costs, top-up availability.
  Future<Wallet> getWallet();

  /// GET /wallet/packages — purchasable credit bundles.
  Future<List<CreditPackage>> getPackages();

  /// GET /wallet/transactions — paginated ledger.
  Future<PaginatedResponse<WalletTransaction>> getTransactions({int page = 1});

  /// POST /wallet/demo-topup — adds demo credits (dev/demo builds). Returns the
  /// new credit balance.
  Future<int> demoTopup();

  /// POST /wallet/checkout — create a Razorpay order for a credit package.
  Future<CheckoutOrder> checkout(int creditPackageId);

  /// POST /wallet/verify — confirm the Razorpay payment and credit the wallet.
  /// Returns the new credit balance.
  Future<int> verify({
    required int paymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  });

  /// POST /wallet/payments/{id}/outcome — report a client-side cancel/failure.
  Future<void> reportOutcome({required int paymentId, required String status});

  /// POST /wallet/iap/verify — validate an Apple/Google store receipt and credit
  /// the wallet. Returns the new credit balance.
  Future<int> verifyIap({
    required String platform,
    required String productId,
    String? receiptData,
    String? purchaseToken,
    String? transactionId,
  });
}

class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  WalletRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<Wallet> getWallet() async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.wallet);
    return ApiEnvelope.object(res.data, Wallet.fromJson);
  }

  @override
  Future<List<CreditPackage>> getPackages() async {
    final res =
        await _client.get<Map<String, dynamic>>(ApiEndpoints.walletPackages);
    final raw = res.data?['data'];
    final out = <CreditPackage>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) out.add(CreditPackage.fromJson(e));
      }
    }
    return out;
  }

  @override
  Future<PaginatedResponse<WalletTransaction>> getTransactions({int page = 1}) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.walletTransactions,
      query: {'page': page, 'per_page': AppConstants.defaultPageSize},
    );
    return ApiEnvelope.list(res.data, WalletTransaction.fromJson);
  }

  @override
  Future<int> demoTopup() async {
    final res = await _client
        .post<Map<String, dynamic>>(ApiEndpoints.walletDemoTopup);
    // Shape: { "data": { "credits_added": 100, "credit_balance": 200 } }
    final data = res.data?['data'];
    if (data is Map && data['credit_balance'] is num) {
      return (data['credit_balance'] as num).toInt();
    }
    return 0;
  }

  @override
  Future<CheckoutOrder> checkout(int creditPackageId) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.walletCheckout,
      data: {'credit_package_id': creditPackageId},
    );
    return ApiEnvelope.object(res.data, CheckoutOrder.fromJson);
  }

  @override
  Future<int> verify({
    required int paymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.walletVerify,
      data: {
        'payment_id': paymentId,
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      },
    );
    final data = res.data?['data'];
    if (data is Map && data['credit_balance'] is num) {
      return (data['credit_balance'] as num).toInt();
    }
    return 0;
  }

  @override
  Future<void> reportOutcome({
    required int paymentId,
    required String status,
  }) async {
    await _client.post<dynamic>(
      ApiEndpoints.walletPaymentOutcome(paymentId),
      data: {'status': status},
    );
  }

  @override
  Future<int> verifyIap({
    required String platform,
    required String productId,
    String? receiptData,
    String? purchaseToken,
    String? transactionId,
  }) async {
    final body = <String, dynamic>{
      'platform': platform,
      'product_id': productId,
      'receipt_data': ?receiptData,
      'purchase_token': ?purchaseToken,
      'transaction_id': ?transactionId,
    };
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.walletIapVerify,
      data: body,
    );
    final data = res.data?['data'];
    if (data is Map && data['credit_balance'] is num) {
      return (data['credit_balance'] as num).toInt();
    }
    return 0;
  }
}
