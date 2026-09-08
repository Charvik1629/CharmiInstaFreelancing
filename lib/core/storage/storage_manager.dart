import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_keys.dart';

/// Central storage facade.
///
/// - Sensitive values (the Bearer token) go through [FlutterSecureStorage].
/// - Non-sensitive flags/cache use [SharedPreferences].
///
/// Features depend on this instead of touching either backend directly, so the
/// storage strategy can change in one place.
class StorageManager {
  StorageManager(this._secure, this._prefs);

  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;

  /// Builds a ready instance. Call once during DI setup.
  static Future<StorageManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage(
      // v11 stores encrypted by default; keychain items available after first unlock.
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    return StorageManager(secure, prefs);
  }

  // ---- Secure ----
  Future<void> writeSecure(String key, String value) =>
      _secure.write(key: key, value: value);

  Future<String?> readSecure(String key) => _secure.read(key: key);

  Future<void> deleteSecure(String key) => _secure.delete(key: key);

  // ---- Preferences ----
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  String? getString(String key) => _prefs.getString(key);

  Future<bool> setBool(String key, {required bool value}) =>
      _prefs.setBool(key, value);

  bool getBool(String key, {bool defaultValue = false}) =>
      _prefs.getBool(key) ?? defaultValue;

  Future<bool> remove(String key) => _prefs.remove(key);

  /// Clears the token + cached user. Used on logout.
  Future<void> clearSession() async {
    await deleteSecure(StorageKeys.authToken);
    await _prefs.remove(StorageKeys.cachedUserJson);
  }
}
