import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'app_loader.dart';

/// Visual variants matching the design's button row.
enum AppButtonVariant { primary, tonal, outline }

/// The app's primary action button.
///
/// - [AppButtonVariant.primary] uses the brand gradient (hero CTAs like
///   "Request this post", "Boost").
/// - [tonal] is a soft filled button; [outline] is a bordered button.
/// Handles loading and disabled states. Reused everywhere so button styling is
/// defined once.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  /// While true the button is disabled and the app's single center loader is
  /// shown (no per-button spinner — one global blocking overlay app-wide).
  final bool isLoading;
  final bool expanded;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) _sync();
  }

  /// Reconciles the global loader with this button's isLoading after the frame
  /// (mutating it during build would be unsafe). Ref-counted + race-safe.
  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final want = mounted && widget.isLoading;
      if (want && !_shown) {
        AppLoader.show();
        _shown = true;
      } else if (!want && _shown) {
        AppLoader.hide();
        _shown = false;
      }
    });
  }

  @override
  void dispose() {
    if (_shown) {
      AppLoader.hide();
      _shown = false;
    }
    super.dispose();
  }

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final child = _Content(label: widget.label, icon: widget.icon);
    final button = switch (widget.variant) {
      AppButtonVariant.primary => _GradientButton(
          enabled: _enabled,
          onPressed: _enabled ? widget.onPressed : null,
          child: child,
        ),
      AppButtonVariant.tonal => _TonalButton(
          onPressed: _enabled ? widget.onPressed : null,
          child: child,
        ),
      AppButtonVariant.outline => _OutlineButton(
          onPressed: _enabled ? widget.onPressed : null,
          child: child,
        ),
    };
    return SizedBox(width: widget.expanded ? double.infinity : null, child: button);
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    // Scale the label down to fit narrow (side-by-side) buttons instead of
    // clipping it — e.g. "Mark as sold" / "Boost post" no longer truncate.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.sm)
          ],
          Text(label, style: style, maxLines: 1, softWrap: false),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.child,
    required this.onPressed,
    required this.enabled,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final nexveero = context.nexveero;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: nexveero.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white),
                child: IconTheme.merge(
                  data: const IconThemeData(color: Colors.white),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TonalButton extends StatelessWidget {
  const _TonalButton({required this.child, required this.onPressed});
  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: child,
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.child, required this.onPressed});
  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
        side: BorderSide(color: context.nexveero.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: child,
    );
  }
}
