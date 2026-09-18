import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';

/// Logs requests/responses/errors to the console (visible in **Logcat** under
/// the `flutter` tag, and in `flutter logs`). Uses [debugPrint] so it surfaces
/// on-device, unlike `dart:developer` logs. Only active when logging is enabled
/// (dev/staging). Never prints the Authorization header value.
class LoggingInterceptor extends Interceptor {
  static const _tag = 'NEXVEERO-HTTP';

  bool get _on => AppConfig.current.enableLogging;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_on) {
      debugPrint('$_tag → ${options.method} ${options.uri}');
      final body = _bodyString(options.data);
      if (body != null) debugPrint('$_tag   body: $body');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_on) {
      debugPrint(
          '$_tag ← ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}');
      final body = _bodyString(response.data);
      if (body != null) debugPrint('$_tag   data: $body');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_on) {
      debugPrint(
          '$_tag ✗ ${err.response?.statusCode ?? '-'} ${err.requestOptions.method} ${err.requestOptions.uri} :: ${err.message}');
      final body = _bodyString(err.response?.data);
      if (body != null) debugPrint('$_tag   error: $body');
    }
    handler.next(err);
  }

  /// A short, printable view of a request/response body (skips file uploads).
  String? _bodyString(Object? data) {
    if (data == null || data is FormData) return null;
    final s = data.toString();
    return s.length > 800 ? '${s.substring(0, 800)}…' : s;
  }
}
