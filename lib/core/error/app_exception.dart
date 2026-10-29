/// Thrown by the data layer (datasources) to carry structured error info up to
/// repositories, which convert it into a [Failure]. Keeps Dio out of domain.
class AppException implements Exception {
  const AppException(
    this.message, {
    this.statusCode,
    this.fieldErrors,
    this.data,
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>>? fieldErrors;

  /// The response envelope's `data` object, when the error carried one (e.g. a
  /// 409 conflict returns `data.conversation_id` for the existing thread).
  final Map<String, dynamic>? data;

  @override
  String toString() => 'AppException($statusCode): $message';
}
