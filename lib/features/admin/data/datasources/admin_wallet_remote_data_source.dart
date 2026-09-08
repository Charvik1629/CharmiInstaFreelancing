import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/wallet_package.dart';
import '../../domain/entities/wallet_settings.dart';

abstract class AdminWalletRemoteDataSource {
  Future<List<WalletPackage>> getPackages();
  Future<WalletPackage> createPackage({
    required String name,
    required int credits,
    required int amountPaise,
    required bool isActive,
    required int sortOrder,
  });
  Future<WalletPackage> updatePackage({
    required int id,
    required String name,
    required int credits,
    required int amountPaise,
    required bool isActive,
    required int sortOrder,
  });
  Future<void> deletePackage(int id);

  Future<WalletSettings> getSettings();
  Future<WalletSettings> updateSettings(Map<String, dynamic> changes);

  /// Returns the user's new credit balance.
  Future<int> adjustUser({
    required int userId,
    required int amount,
    required String direction, // 'credit' | 'debit'
    String? note,
  });
}

class AdminWalletRemoteDataSourceImpl implements AdminWalletRemoteDataSource {
  AdminWalletRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  Map<String, dynamic> _packageBody({
    required String name,
    required int credits,
    required int amountPaise,
    required bool isActive,
    required int sortOrder,
  }) =>
      {
        'name': name,
        'credits': credits,
        'amount_paise': amountPaise,
        'is_active': isActive,
        'sort_order': sortOrder,
      };

  @override
  Future<List<WalletPackage>> getPackages() async {
    final res = await _client
        .get<Map<String, dynamic>>(ApiEndpoints.adminWalletPackages);
    return ApiEnvelope.list(res.data, WalletPackage.fromJson).items;
  }

  @override
  Future<WalletPackage> createPackage({
    required String name,
    required int credits,
    required int amountPaise,
    required bool isActive,
    required int sortOrder,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.adminWalletPackages,
      data: _packageBody(
        name: name,
        credits: credits,
        amountPaise: amountPaise,
        isActive: isActive,
        sortOrder: sortOrder,
      ),
    );
    return ApiEnvelope.object(res.data, WalletPackage.fromJson);
  }

  @override
  Future<WalletPackage> updatePackage({
    required int id,
    required String name,
    required int credits,
    required int amountPaise,
    required bool isActive,
    required int sortOrder,
  }) async {
    final res = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.adminWalletPackage(id),
      data: _packageBody(
        name: name,
        credits: credits,
        amountPaise: amountPaise,
        isActive: isActive,
        sortOrder: sortOrder,
      ),
    );
    return ApiEnvelope.object(res.data, WalletPackage.fromJson);
  }

  @override
  Future<void> deletePackage(int id) async {
    await _client.delete<dynamic>(ApiEndpoints.adminWalletPackage(id));
  }

  @override
  Future<WalletSettings> getSettings() async {
    final res = await _client
        .get<Map<String, dynamic>>(ApiEndpoints.adminWalletSettings);
    return ApiEnvelope.object(res.data, WalletSettings.fromJson);
  }

  @override
  Future<WalletSettings> updateSettings(Map<String, dynamic> changes) async {
    final res = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.adminWalletSettings,
      data: changes,
    );
    return ApiEnvelope.object(res.data, WalletSettings.fromJson);
  }

  @override
  Future<int> adjustUser({
    required int userId,
    required int amount,
    required String direction,
    String? note,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.adminWalletAdjust(userId),
      data: {
        'amount': amount,
        'direction': direction,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    // Shape: { "data": { "user_id": 3, "credit_balance": 150 } }
    final data = res.data?['data'];
    if (data is Map && data['credit_balance'] is num) {
      return (data['credit_balance'] as num).toInt();
    }
    return 0;
  }
}
