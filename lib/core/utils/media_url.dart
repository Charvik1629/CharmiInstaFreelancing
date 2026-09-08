import '../config/app_config.dart';

/// Resolves a server-relative media path (e.g. `/media/avatars/x.jpg`) to an
/// absolute URL against the configured API host. Absolute URLs pass through;
/// null/empty stays null so callers can fall back to a placeholder.
class MediaUrl {
  MediaUrl._();

  static String? resolve(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '${AppConfig.current.baseUrl}$path';
  }
}
