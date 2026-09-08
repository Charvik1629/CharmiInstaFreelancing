/// Centralized Google Mobile Ads configuration for the feed.
///
/// Ad frequency lives here so it can be tuned in one place instead of being
/// hardcoded through the feed logic.
class AdConfig {
  AdConfig._();

  /// Insert one native/banner ad after every N posts (spec: ~5–6).
  static const int postsBetweenAds = 5;

  /// Do not show an ad before at least this many posts are visible.
  static const int minPostsBeforeFirstAd = 3;

  /// Max concurrent ad instances kept in memory to avoid waste.
  static const int maxCachedAds = 5;

  /// Google's official test ad unit ids. Replaced with real ids for release
  /// builds. Kept centralized so nothing hardcodes an ad unit id.
  static const String androidTestBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String iosTestBanner =
      'ca-app-pub-3940256099942544/2934735716';

  static const String androidTestNative =
      'ca-app-pub-3940256099942544/2247696110';
  static const String iosTestNative =
      'ca-app-pub-3940256099942544/3986624511';

  /// Toggle to use test ids. Must be true until real ad units + AdMob app id
  /// are provisioned.
  static const bool useTestAds = true;

  /// Native ad unit id for the current platform. Swap the non-test branches for
  /// the real AdMob unit ids when [useTestAds] is turned off.
  static String nativeUnitId({required bool isIOS}) {
    if (useTestAds) return isIOS ? iosTestNative : androidTestNative;
    return isIOS ? 'REPLACE_IOS_NATIVE_UNIT' : 'REPLACE_ANDROID_NATIVE_UNIT';
  }

  /// Banner ad unit id (used as a fallback if the native ad fails).
  static String bannerUnitId({required bool isIOS}) {
    if (useTestAds) return isIOS ? iosTestBanner : androidTestBanner;
    return isIOS ? 'REPLACE_IOS_BANNER_UNIT' : 'REPLACE_ANDROID_BANNER_UNIT';
  }
}
