import 'dart:io' show Platform;

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../constants/ad_config.dart';
import '../utils/logger.dart';

/// Thin wrapper around the Google Mobile Ads SDK. Centralizes one-time
/// initialization and ad-unit resolution so the feed never touches SDK setup.
class AdService {
  AdService._();

  static bool _initialized = false;

  /// Idempotent SDK init. Safe to call at startup; failures are swallowed so a
  /// missing/misconfigured ads setup never blocks the app.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      AppLogger.w('MobileAds init failed: $e', tag: 'Ads');
    }
  }

  static String get nativeAdUnitId =>
      AdConfig.nativeUnitId(isIOS: Platform.isIOS);

  static String get bannerAdUnitId =>
      AdConfig.bannerUnitId(isIOS: Platform.isIOS);
}
