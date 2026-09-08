import 'app_environment.dart';

/// Single source of truth for environment-dependent configuration.
///
/// The API **Base URL is centralized here**. It is not yet known, so a
/// placeholder is used per environment. When the real URL is provided, change
/// it in ONE place — no other code hardcodes a base URL.
class AppConfig {
  const AppConfig._({
    required this.environment,
    required this.baseUrl,
    required this.apiPrefix,
    required this.enableLogging,
    required this.connectTimeout,
    required this.receiveTimeout,
  });

  final AppEnvironment environment;

  /// Scheme + host (+ optional port). Example once known:
  /// `https://api.nexveero.app`. Placeholder until the backend URL is provided.
  final String baseUrl;

  /// Version prefix from the API docs (Base URL is `/api/v1`).
  final String apiPrefix;

  final bool enableLogging;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// Full API root, e.g. `https://api.nexveero.app/api/v1`.
  String get apiBaseUrl => '$baseUrl$apiPrefix';

  bool get isProd => environment == AppEnvironment.prod;

  /// Returns a copy with overrides. Useful for injecting the real base URL at
  /// runtime (e.g. from remote config) once the backend URL is known.
  AppConfig copyWith({
    AppEnvironment? environment,
    String? baseUrl,
    String? apiPrefix,
    bool? enableLogging,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) {
    return AppConfig._(
      environment: environment ?? this.environment,
      baseUrl: baseUrl ?? this.baseUrl,
      apiPrefix: apiPrefix ?? this.apiPrefix,
      enableLogging: enableLogging ?? this.enableLogging,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
    );
  }

  // ---- Placeholders. Replace [_baseUrl] values when the real URL is known. ----
  static const String _devBaseUrl = 'https://REPLACE_ME.dev.nexveero.app';
  static const String _stagingBaseUrl = 'https://REPLACE_ME.staging.nexveero.app';
  static const String _prodBaseUrl = 'https://REPLACE_ME.nexveero.app';

  static const AppConfig dev = AppConfig._(
    environment: AppEnvironment.dev,
    baseUrl: _devBaseUrl,
    apiPrefix: '/api/v1',
    enableLogging: true,
    connectTimeout: Duration(seconds: 20),
    receiveTimeout: Duration(seconds: 20),
  );

  static const AppConfig staging = AppConfig._(
    environment: AppEnvironment.staging,
    baseUrl: _stagingBaseUrl,
    apiPrefix: '/api/v1',
    enableLogging: true,
    connectTimeout: Duration(seconds: 20),
    receiveTimeout: Duration(seconds: 20),
  );

  static const AppConfig prod = AppConfig._(
    environment: AppEnvironment.prod,
    baseUrl: _prodBaseUrl,
    apiPrefix: '/api/v1',
    enableLogging: false,
    connectTimeout: Duration(seconds: 20),
    receiveTimeout: Duration(seconds: 20),
  );

  /// Optional compile-time base URL override:
  /// `flutter run --dart-define=BASE_URL=https://api.example.com`.
  /// Lets us point at the real backend (or a local mock) without editing code.
  static const String _envBaseUrl = String.fromEnvironment('BASE_URL');

  /// The active config. Defaults to [dev]; if BASE_URL is provided at build
  /// time it overrides the placeholder so the app talks to a real server.
  static AppConfig current =
      _envBaseUrl.isEmpty ? dev : dev.copyWith(baseUrl: _envBaseUrl);

  /// Whether the base URL is still a placeholder. UI/logging can warn on this
  /// so a missing backend URL is obvious rather than a silent network failure.
  bool get isBaseUrlConfigured => !baseUrl.contains('REPLACE_ME');
}
