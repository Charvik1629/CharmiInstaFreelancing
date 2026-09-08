import '../config/app_config.dart';
import '../error/app_exception.dart';
import '../error/failure.dart';
import '../utils/logger.dart';
import '../utils/result.dart';

/// Shared repository behavior: run a datasource call and normalize any
/// [AppException] (or unexpected error) into a typed [Failure], returning a
/// [Result]. Feature repositories mix this in to avoid duplicating try/catch.
mixin BaseRepository {
  Future<Result<T>> guard<T>(Future<T> Function() request) async {
    if (!AppConfig.current.isBaseUrlConfigured) {
      return const Err(ConfigFailure());
    }
    try {
      return Success(await request());
    } on AppException catch (e) {
      return Err(_toFailure(e));
    } catch (e, s) {
      AppLogger.e('Unhandled repository error', error: e, stackTrace: s);
      return const Err(UnknownFailure());
    }
  }

  Failure _toFailure(AppException e) {
    switch (e.statusCode) {
      case 401:
        return AuthFailure(e.message);
      case 402:
        return InsufficientCreditsFailure(e.message);
      case 403:
        return ForbiddenFailure(e.message);
      case 404:
        return NotFoundFailure(e.message);
      case 422:
        return ValidationFailure(e.message, fieldErrors: e.fieldErrors);
      case null:
        // No HTTP status → transport error (timeout / no connection).
        return NetworkFailure(e.message);
      default:
        if ((e.statusCode ?? 0) >= 500) {
          return ServerFailure(e.message, statusCode: e.statusCode);
        }
        return UnknownFailure(e.message);
    }
  }
}
