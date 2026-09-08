/// Thrown by the data layer (datasources) to carry structured error info up to
/// repositories, which convert it into a [Failure]. Keeps Dio out of domain.
class AppException implements Exception {
  const AppException(
    this.message, {
    this.statusCode,
    this.fieldErrors,
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>>? fieldErrors;

  @override
  String toString() => 'AppException($statusCode): $message';
}
