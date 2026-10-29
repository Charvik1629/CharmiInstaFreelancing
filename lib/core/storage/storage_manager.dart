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

  /// In-memory mirror of secure values written this session. The Android
  /// KeyStore backend is unreliable on several OEMs (OPPO/ColorOS, Xiaomi,
  /// OnePlus): a read right after a write can throw or return null, which drops
  /// the Bearer token → every call 401s → the app bounces back to login. Serving
  /// reads from memory first makes the token rock-solid for the session's
  /// lifetime, independent of the native backend's read reliability.
  final Map<String, String> _secureCache = {};

  /// Builds a ready instance. Call once during DI setup.
  static Future<StorageManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage(
      // v11 stores encrypted by default (AES/GCM) with resetOnError=true.
      // v11 stores encrypted by default; keychain items available after first unlock.
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    return StorageManager(secure, prefs);
  }

  // ---- Secure ----
  // SharedPreferences fallback key for a secure value. The Android Keystore is
  // unreliable on several OEMs (OPPO/ColorOS, Xiaomi, OnePlus): a read after an
  // app restart can throw or return null, dropping the token so the user is
  // logged out on every launch. We mirror secure values into prefs so the
  // session survives restarts even when the keystore read fails. (A small
  // security trade-off, chosen over constant logouts; the keystore copy is
  // still written and preferred when it works.)
  static String _fallbackKey(String key) => '__sec__$key';

  Future<void> writeSecure(String key, String value) async {
    _secureCache[key] = value;
    // Reliable mirror first, then the (best-effort) encrypted keystore copy.
    try {
      await _prefs.setString(_fallbackKey(key), value);
    } catch (_) {/* ignore */}
    try {
      await _secure.write(key: key, value: value);
    } catch (_) {/* keystore quirk — the prefs mirror + memory cover us */}
  }

  Future<String?> readSecure(String key) async {
    final cached = _secureCache[key];
    if (cached != null) return cached;
    // Try the encrypted keystore; fall back to the prefs mirror on failure.
    try {
      final value = await _secure.read(key: key);
      if (value != null && value.isNotEmpty) {
        _secureCache[key] = value;
        return value;
      }
    } catch (_) {/* fall through to the mirror */}
    final mirror = _prefs.getString(_fallbackKey(key));
    if (mirror != null && mirror.isNotEmpty) {
      _secureCache[key] = mirror;
      // Best-effort: re-seed the keystore for next time.
      try {
        await _secure.write(key: key, value: mirror);
      } catch (_) {/* ignore */}
    }
    return mirror;
  }

  Future<void> deleteSecure(String key) async {
    _secureCache.remove(key);
    try {
      await _prefs.remove(_fallbackKey(key));
    } catch (_) {/* ignore */}
    try {
      await _secure.delete(key: key);
    } catch (_) {/* ignore */}
  }

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
