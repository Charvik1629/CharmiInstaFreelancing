import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Visual variants matching the design's button row.
enum AppButtonVariant { primary, tonal, outline }

/// The app's primary action button.
///
/// - [AppButtonVariant.primary] uses the brand gradient (hero CTAs like
///   "Request this post", "Boost").
/// - [tonal] is a soft filled button; [outline] is a bordered button.
/// Handles loading and disabled states. Reused everywhere so button styling is
/// defined once.
class AppButton extends StatelessWidget {
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
  final bool isLoading;
  final bool expanded;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final child = _Content(label: label, icon: icon, isLoading: isLoading);
    final button = switch (variant) {
      AppButtonVariant.primary => _GradientButton(
          enabled: _enabled,
          onPressed: _enabled ? onPressed : null,
          child: child,
        ),
      AppButtonVariant.tonal => _TonalButton(
          onPressed: _enabled ? onPressed : null,
          child: child,
        ),
      AppButtonVariant.outline => _OutlineButton(
          onPressed: _enabled ? onPressed : null,
          child: child,
        ),
    };
    return SizedBox(width: expanded ? double.infinity : null, child: button);
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.label, this.icon, required this.isLoading});
  final String label;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
      );
    }
    final style = Theme.of(context).textTheme.titleMedium;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: AppSpacing.sm)],
        Flexible(child: Text(label, style: style, overflow: TextOverflow.ellipsis)),
      ],
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
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        side: BorderSide(color: context.nexveero.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: child,
    );
  }
}
