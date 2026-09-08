import 'dart:convert';

import '../../../../core/models/user.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../../../core/storage/storage_manager.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl with BaseRepository implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._storage);

  final AuthRemoteDataSource _remote;
  final StorageManager _storage;

  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
  }) async {
    final result = await guard(
      () => _remote.login(email: email, password: password),
    );
    await _persistOnSuccess(result);
    return result;
  }

  @override
  Future<Result<User>> register({
    required String name,
    required String businessName,
    required String phone,
    required String email,
    String? gstNumber,
    String? panNumber,
    String? aadhaarNumber,
    String? referralCode,
    required String password,
    required String passwordConfirmation,
  }) {
    // No token is issued at register (account is pending), so nothing to persist.
    return guard(
      () => _remote.register(
        name: name,
        businessName: businessName,
        phone: phone,
        email: email,
        gstNumber: gstNumber,
        panNumber: panNumber,
        aadhaarNumber: aadhaarNumber,
        referralCode: referralCode,
        password: password,
        passwordConfirmation: passwordConfirmation,
      ),
    );
  }

  @override
  Future<Result<User>> me() async {
    final result = await guard(_remote.me);
    if (result case Success(value: final user)) {
      await _cacheUser(user);
    }
    return result;
  }

  @override
  Future<void> logout() async {
    // Best effort: revoke server-side, but always clear locally.
    try {
      await _remote.logout();
    } catch (e) {
      AppLogger.w('Logout API failed (clearing local session anyway): $e');
    }
    await _storage.clearSession();
  }

  @override
  Future<void> persistSession(AuthSession session) async {
    await _storage.writeSecure(StorageKeys.authToken, session.token);
    await _cacheUser(session.user);
  }

  @override
  User? cachedUser() {
    final raw = _storage.getString(StorageKeys.cachedUserJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cacheUser(User user) => _cacheUser(user);

  @override
  Future<bool> hasToken() async {
    final token = await _storage.readSecure(StorageKeys.authToken);
    return token != null && token.isNotEmpty;
  }

  Future<void> _persistOnSuccess(Result<AuthSession> result) async {
    if (result case Success(value: final session)) {
      await persistSession(session);
    }
  }

  Future<void> _cacheUser(User user) =>
      _storage.setString(StorageKeys.cachedUserJson, jsonEncode(user.toJson()));

  @override
  Future<Result<void>> sendOtp(String identifier) =>
      guard(() => _remote.sendOtp(identifier));

  @override
  Future<Result<void>> verifyOtp({required String identifier, required String code}) =>
      guard(() => _remote.verifyOtp(identifier: identifier, code: code));

  @override
  Future<Result<void>> forgotPassword(String email) =>
      guard(() => _remote.forgotPassword(email));

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) =>
      guard(() => _remote.changePassword(
            currentPassword: currentPassword,
            password: password,
            passwordConfirmation: passwordConfirmation,
          ));
}
