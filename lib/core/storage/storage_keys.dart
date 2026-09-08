/// Keys used with [StorageManager]. Centralized to avoid typos and collisions.
class StorageKeys {
  StorageKeys._();

  // Secure (flutter_secure_storage)
  static const String authToken = 'auth_token';

  // Preferences (shared_preferences)
  static const String onboardingSeen = 'onboarding_seen';
  static const String cachedUserJson = 'cached_user_json';
  static const String themeMode = 'theme_mode';
  static const String recentSearches = 'recent_searches';
}
