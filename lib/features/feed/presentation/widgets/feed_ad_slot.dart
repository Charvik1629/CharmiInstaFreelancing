import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/ads/ad_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// A single in-feed ad (design: "Ad · Sponsored · Google" card).
///
/// Loads a **native** ad first (rendered with the SDK's native template, so no
/// platform ad factory is needed). If the native ad fails, it falls back to a
/// **banner** ad so a real device/emulator still shows something. If both fail,
/// the slot collapses to nothing — the feed keeps working either way. Each slot
/// owns its ad(s) and disposes them when scrolled away.
class FeedAdSlot extends StatefulWidget {
  const FeedAdSlot({super.key});

  @override
  State<FeedAdSlot> createState() => _FeedAdSlotState();
}

class _FeedAdSlotState extends State<FeedAdSlot> {
  NativeAd? _native;
  BannerAd? _banner;
  bool _nativeLoaded = false;
  bool _bannerLoaded = false;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_native == null && _banner == null) _loadNative();
  }

  void _loadNative() {
    final ad = NativeAd(
      adUnitId: AdService.nativeAdUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Theme.of(context).colorScheme.surface,
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _nativeLoaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _native = null;
          _loadBanner(); // fall back
        },
      ),
    );
    _native = ad;
    ad.load();
  }

  void _loadBanner() {
    final ad = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _bannerLoaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _banner = null;
          if (mounted) setState(() => _failed = true);
        },
      ),
    );
    _banner = ad;
    ad.load();
  }

  @override
  void dispose() {
    _native?.dispose();
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();

    final Widget? adView = _nativeLoaded && _native != null
        ? AdWidget(ad: _native!)
        : (_bannerLoaded && _banner != null ? AdWidget(ad: _banner!) : null);

    if (adView == null) return const SizedBox(height: 8); // quiet while loading

    final isBanner = _bannerLoaded && !_nativeLoaded;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      constraints: isBanner
          ? const BoxConstraints(minHeight: 250, maxHeight: 300)
          : const BoxConstraints(minHeight: 320, maxHeight: 360),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.nexveero.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: isBanner
          ? Center(child: SizedBox(width: 300, height: 250, child: adView))
          : adView,
    );
  }
}
