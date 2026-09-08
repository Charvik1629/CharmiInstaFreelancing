import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../error/app_exception.dart';
import '../storage/storage_manager.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Reusable HTTP client wrapping Dio.
///
/// - Base URL comes from [AppConfig] (single source of truth).
/// - Auth header + logging handled by interceptors.
/// - Every Dio error is translated into a transport-agnostic [AppException];
///   callers (datasources) never see a [DioException].
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  /// Factory that wires timeouts, base URL, and interceptors.
  factory ApiClient.create({
    required StorageManager storage,
    void Function()? onUnauthorized,
    Dio? dio,
  }) {
    final config = AppConfig.current;
    final client = dio ?? Dio();
    client.options
      ..baseUrl = config.apiBaseUrl
      ..connectTimeout = config.connectTimeout
      ..receiveTimeout = config.receiveTimeout
      ..headers['Accept'] = 'application/json';
    client.interceptors.addAll([
      AuthInterceptor(storage, onUnauthorized: onUnauthorized),
      if (config.enableLogging) LoggingInterceptor(),
    ]);
    return ApiClient(client);
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
  }) =>
      _guard(() => _dio.get<T>(path, queryParameters: query));

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) =>
      _guard(() => _dio.post<T>(path, data: data, queryParameters: query));

  Future<Response<T>> put<T>(String path, {Object? data}) =>
      _guard(() => _dio.put<T>(path, data: data));

  Future<Response<T>> patch<T>(String path, {Object? data}) =>
      _guard(() => _dio.patch<T>(path, data: data));

  Future<Response<T>> delete<T>(String path, {Object? data}) =>
      _guard(() => _dio.delete<T>(path, data: data));

  /// Runs a Dio call and converts failures into [AppException].
  Future<Response<T>> _guard<T>(Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  AppException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException('Connection timed out. Please try again.');
      case DioExceptionType.connectionError:
        return const AppException('No internet connection.');
      case DioExceptionType.cancel:
        return const AppException('Request cancelled.');
      case DioExceptionType.badCertificate:
        return const AppException('Secure connection failed.');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return _mapResponse(e);
      default:
        // Covers newer Dio variants (e.g. transformTimeout).
        return _mapResponse(e);
    }
  }

  AppException _mapResponse(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;

    String message = 'Something went wrong.';
    Map<String, List<String>>? fieldErrors;

    if (body is Map<String, dynamic>) {
      if (body['message'] is String) message = body['message'] as String;
      final errors = body['errors'];
      if (errors is Map<String, dynamic>) {
        fieldErrors = errors.map(
          (k, v) => MapEntry(
            k,
            (v is List) ? v.map((e) => '$e').toList() : ['$v'],
          ),
        );
        // Prefer the first field error as the surfaced message for 422s.
        if (status == 422 && fieldErrors.isNotEmpty) {
          message = fieldErrors.values.first.first;
        }
      }
    }

    return AppException(message, statusCode: status, fieldErrors: fieldErrors);
  }
}
