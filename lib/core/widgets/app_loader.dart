import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// The app's single, universal blocking loader.
///
/// One dimmed overlay with the brand spinner, mounted once at the app root via
/// [AppLoader.host] (see `MaterialApp.builder`). Trigger it from anywhere —
/// there's no per-screen widget to add:
///
/// ```dart
/// await AppLoader.run(repo.pay(orderId));      // wraps a future
/// // or manually:
/// AppLoader.show();  ... ;  AppLoader.hide();
/// ```
///
/// Calls are ref-counted, so overlapping actions keep the loader up until the
/// last one finishes.
class AppLoader {
  AppLoader._();

  static final ValueNotifier<int> _count = ValueNotifier<int>(0);

  /// Whether the overlay is currently showing.
  static bool get isVisible => _count.value > 0;

  /// Show the loader (ref-counted — pair every [show] with a [hide]).
  static void show() => _count.value++;

  /// Hide one [show]. Safe to over-call; never drops below zero.
  static void hide() {
    if (_count.value > 0) _count.value--;
  }

  /// Force the loader off regardless of ref-count (e.g. on a hard navigation).
  static void reset() => _count.value = 0;

  /// Run [future] with the loader up, hiding it even if [future] throws.
  static Future<T> run<T>(Future<T> future) async {
    show();
    try {
      return await future;
    } finally {
      hide();
    }
  }

  /// Wraps the app so the overlay renders above every screen. Use in
  /// `MaterialApp.builder`.
  static Widget host(BuildContext context, Widget? child) {
    return Stack(
      children: [
        child ?? const SizedBox.shrink(),
        ValueListenableBuilder<int>(
          valueListenable: _count,
          builder: (context, count, _) =>
              count > 0 ? const _LoaderScrim() : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _LoaderScrim extends StatelessWidget {
  const _LoaderScrim();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: Stack(
        children: [
          // Blocks all taps + the hardware back gesture underneath.
          ModalBarrier(dismissible: false, color: Color(0x47000000)),
          Center(child: _BrandSpinner()),
        ],
      ),
    );
  }
}

class _BrandSpinner extends StatelessWidget {
  const _BrandSpinner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor:
              AlwaysStoppedAnimation<Color>(context.nexveero.gradientEnd),
          backgroundColor: context.nexveero.gradientStart.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}
