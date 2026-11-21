import 'dart:io' show Platform;
import 'dart:math';

import '../../../../core/storage/storage_keys.dart';
import '../../../../core/storage/storage_manager.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/models/user.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/auth_session.dart';

/// Raw calls to the authentication endpoints. Throws [AppException] on failure
/// (mapped by [ApiClient]); the repository converts those to typed failures.
abstract class AuthRemoteDataSource {
  /// [identifier] is the username, email, or mobile number.
  Future<AuthSession> login({
    required String identifier,
    required String password,
  });

  /// Creates a B2B account. Returns the created [User] (with
  /// `approval_status: pending`) — no token is issued until an admin approves.
  Future<User> register({
    required String name,
    required String username,
    required String businessName,
    required String phone,
    required String email,
    String? gstNumber,
    String? panNumber,
    String? aadhaarNumber,
    String? referralCode,
    required String password,
    required String passwordConfirmation,
  });
  Future<User> me();
  Future<void> logout();

  /// DELETE /account — permanently deletes the current account.
  Future<void> deleteAccount(String password);

  Future<void> sendOtp(String identifier);
  Future<void> verifyOtp({required String identifier, required String code});
  Future<void> forgotPassword(String email);
  Future<void> resetPassword({
    required String login,
    required String token,
    required String password,
    required String passwordConfirmation,
  });
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._client, this._storage);

  final ApiClient _client;
  final StorageManager _storage;

  /// Labels the Sanctum token so it can be revoked per device later.
  String get _deviceName {
    var id = _storage.getString(StorageKeys.installationId);
    if (id == null || id.isEmpty) {
      throw StateError('Installation ID must be initialized before login');
    }
    return '${Platform.isIOS ? 'ios' : 'android'}-$id';
  }

  static Future<void> initializeInstallation(StorageManager storage) async {
    if (storage.getString(StorageKeys.installationId)?.isNotEmpty ?? false) {
      return;
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await storage.setString(StorageKeys.installationId, id);
  }

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      // `login` accepts username, email, or mobile number.
      data: {
        'login': identifier,
        'password': password,
        'device_name': _deviceName,
      },
    );
    return ApiEnvelope.object(res.data, AuthSession.fromJson);
  }

  @override
  Future<User> register({
    required String name,
    required String username,
    required String businessName,
    required String phone,
    required String email,
    String? gstNumber,
    String? panNumber,
    String? aadhaarNumber,
    String? referralCode,
    required String password,
    required String passwordConfirmation,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      data: {
        'name': name,
        'username': username,
        'business_name': businessName,
        'phone': phone,
        'email': email,
        if (gstNumber != null && gstNumber.isNotEmpty) 'gst_number': gstNumber,
        if (panNumber != null && panNumber.isNotEmpty) 'pan_number': panNumber,
        if (aadhaarNumber != null && aadhaarNumber.isNotEmpty)
          'aadhaar_number': aadhaarNumber,
        if (referralCode != null && referralCode.isNotEmpty)
          'referral_code': referralCode,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'device_name': _deviceName,
      },
    );
    // Envelope: { data: { user: {...}, approval_status: "pending" } }. No token.
    return ApiEnvelope.object(
      res.data,
      (m) => User.fromJson(
        m['user'] is Map<String, dynamic>
            ? m['user'] as Map<String, dynamic>
            : m,
      ),
    );
  }

  @override
  Future<User> me() async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.me);
    return ApiEnvelope.object(res.data, User.fromJson);
  }

  @override
  Future<void> deleteAccount(String password) async {
    await _client.delete<dynamic>(
      ApiEndpoints.account,
      data: {'password': password, 'confirmation': 'DELETE'},
    );
  }

  @override
  Future<void> logout() async {
    await _client.post<dynamic>(ApiEndpoints.logout);
  }

  @override
  Future<void> sendOtp(String identifier) async {
    await _client.post<dynamic>(
      ApiEndpoints.otpSend,
      data: {'identifier': identifier},
    );
  }

  @override
  Future<void> verifyOtp({
    required String identifier,
    required String code,
  }) async {
    await _client.post<dynamic>(
      ApiEndpoints.otpVerify,
      data: {'identifier': identifier, 'code': code},
    );
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _client.post<dynamic>(
      ApiEndpoints.passwordForgot,
      data: {'login': email},
    );
  }

  @override
  Future<void> resetPassword({
    required String login,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.post<dynamic>(
      ApiEndpoints.passwordReset,
      data: {
        'login': login,
        'token': token,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.post<dynamic>(
      ApiEndpoints.passwordChange,
      data: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }
}
