import 'package:dio/dio.dart';

import '../../constants/app_constants.dart';
import '../../storage/storage_keys.dart';
import '../../storage/storage_manager.dart';

/// Attaches `Authorization: Bearer {token}` and `Accept: application/json` to
/// every request when a token is stored. On 401 it clears the stored session
/// so the app can route back to login (handled by the auth layer listening to
/// storage / an unauthorized callback).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, {this.onUnauthorized});

  final StorageManager _storage;
  final void Function()? onUnauthorized;
  bool _clearingSession = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['Accept'] = AppConstants.acceptJson;
    final token = await _storage.readSecure(StorageKeys.authToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = '${AppConstants.bearerPrefix}$token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final authorization = err.requestOptions.headers['Authorization'];
    if (err.response?.statusCode == 401 &&
        authorization is String &&
        !_clearingSession) {
      _clearingSession = true;
      try {
        final currentToken = await _storage.readSecure(StorageKeys.authToken);
        // Ignore failures from requests sent before a newer login completed.
        if (currentToken != null &&
            authorization == '${AppConstants.bearerPrefix}$currentToken') {
          await _storage.clearSession();
          onUnauthorized?.call();
        }
      } finally {
        _clearingSession = false;
      }
    }
    handler.next(err);
  }
}
