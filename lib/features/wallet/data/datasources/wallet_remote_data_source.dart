import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
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
}
