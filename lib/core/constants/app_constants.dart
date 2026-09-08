/// App-wide constants that are not environment-specific.
class AppConstants {
  AppConstants._();

  static const String appName = 'Nexveero';

  /// Default page size for paginated lists (API default is 20).
  static const int defaultPageSize = 20;

  /// Header values used across requests.
  static const String acceptJson = 'application/json';
  static const String bearerPrefix = 'Bearer ';
}
