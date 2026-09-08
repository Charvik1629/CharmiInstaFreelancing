import 'package:dio/dio.dart';

import '../../utils/logger.dart';

/// Logs requests/responses/errors only when logging is enabled (see
/// [AppLogger]). Never logs the Authorization header value.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.d('→ ${options.method} ${options.uri}', tag: 'HTTP');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    AppLogger.d(
      '← ${response.statusCode} ${response.requestOptions.uri}',
      tag: 'HTTP',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.w(
      '✗ ${err.response?.statusCode ?? '-'} ${err.requestOptions.uri} :: ${err.message}',
      tag: 'HTTP',
    );
    handler.next(err);
  }
}
