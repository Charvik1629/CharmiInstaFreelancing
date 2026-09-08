import 'dart:developer' as developer;

import '../config/app_config.dart';

/// Thin logging facade. Respects [AppConfig.enableLogging] so production builds
/// stay quiet. Centralized so we never scatter raw `print` calls.
class AppLogger {
  AppLogger._();

  static bool get _enabled => AppConfig.current.enableLogging;

  static void d(String message, {String tag = 'Nexveero'}) {
    if (_enabled) developer.log(message, name: tag, level: 500);
  }

  static void i(String message, {String tag = 'Nexveero'}) {
    if (_enabled) developer.log(message, name: tag, level: 800);
  }

  static void w(String message, {String tag = 'Nexveero'}) {
    if (_enabled) developer.log(message, name: tag, level: 900);
  }

  static void e(
    String message, {
    String tag = 'Nexveero',
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Errors are always logged; details only when logging is enabled.
    developer.log(
      message,
      name: tag,
      level: 1000,
      error: _enabled ? error : null,
      stackTrace: _enabled ? stackTrace : null,
    );
  }
}
