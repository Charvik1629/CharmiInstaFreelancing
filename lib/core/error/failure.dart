import 'package:equatable/equatable.dart';

/// A user-facing, transport-agnostic error. Repositories translate raw
/// exceptions (Dio, platform, parsing) into a [Failure] so the presentation
/// layer never depends on networking types.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.statusCode, this.fieldErrors});

  final String message;
  final int? statusCode;

  /// Field-level validation messages from a 422 response
  /// (`errors: { field: [..] }`). Null when not a validation error.
  final Map<String, List<String>>? fieldErrors;

  @override
  List<Object?> get props => [message, statusCode, fieldErrors];
}

/// No connectivity, DNS failure, or timeouts.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

/// 5xx or unexpected server behavior.
class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.statusCode});
}

/// 401 — token missing or expired. Forces a re-login.
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Session expired. Please sign in again.'])
      : super(statusCode: 401);
}

/// 403 — authenticated but not allowed (e.g. account pending/rejected approval,
/// or insufficient role). Kept distinct from [AuthFailure] so login can route a
/// pending/rejected account to the approval screen instead of forcing logout.
class ForbiddenFailure extends Failure {
  const ForbiddenFailure([super.message = 'You do not have access to this.'])
      : super(statusCode: 403);
}

/// 422 — validation errors with per-field details.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.fieldErrors})
      : super(statusCode: 422);
}

/// 402 — insufficient wallet credits (posting/boost).
class InsufficientCreditsFailure extends Failure {
  const InsufficientCreditsFailure(super.message) : super(statusCode: 402);
}

/// 404.
class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Not found.'])
      : super(statusCode: 404);
}

/// Response body could not be parsed into the expected model.
class ParsingFailure extends Failure {
  const ParsingFailure([super.message = 'Unexpected response from server.']);
}

/// Base URL still a placeholder — surfaced clearly instead of a raw DNS error.
class ConfigFailure extends Failure {
  const ConfigFailure([
    super.message = 'API base URL is not configured yet.',
  ]);
}

/// Anything not otherwise classified.
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong.']);
}
