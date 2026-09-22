import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';
import 'app_text_field.dart';

/// Overlay helpers so dialogs/sheets/snackbars look consistent app-wide.
class AppOverlays {
  AppOverlays._();

  /// Confirmation dialog styled to the design (rounded card, optional tinted
  /// icon, Cancel + Confirm buttons). Returns true on confirm. Destructive
  /// confirms use the error colour for the icon + primary button.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final nex = ctx.nexveero;
        final scheme = Theme.of(ctx).colorScheme;
        final accent = destructive ? scheme.error : scheme.primary;
        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null || destructive)
                  Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                        icon ?? (destructive ? Icons.warning_amber_rounded : Icons.help_outline),
                        color: accent,
                        size: 26),
                  ),
                Text(title,
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.titleLarge),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: nex.textSecondary, height: 1.45)),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: cancelLabel,
                        variant: AppButtonVariant.outline,
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: destructive
                          ? _DangerButton(
                              label: confirmLabel,
                              onPressed: () => Navigator.of(ctx).pop(true),
                            )
                          : AppButton(
                              label: confirmLabel,
                              onPressed: () => Navigator.of(ctx).pop(true),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  /// Styled single-field input dialog (Aurora Bloom). Returns the entered text,
  /// or null if cancelled.
  static Future<String?> prompt(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    int maxLines = 1,
    String confirmLabel = 'Save',
  }) {
    final ctrl = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(controller: ctrl, hint: hint, maxLines: maxLines),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancel',
                      variant: AppButtonVariant.outline,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: confirmLabel,
                      onPressed: () =>
                          Navigator.of(ctx).pop(ctrl.text.trim()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Modal bottom sheet with a drag handle and a title (design: Boost, menus).
  static Future<T?> sheet<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      builder: (ctx) => SafeArea(
        child: Padding(
          // Lift the sheet above the on-screen keyboard so text fields inside it
          // (Ask a question, Make an offer, …) stay visible while typing.
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: AppSpacing.lg + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: ctx.nexveero.border,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              builder(ctx),
            ],
          ),
        ),
      ),
    );
  }

  /// Snackbar with an optional action (design: "Post published · Undo").
  static void snack(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: (actionLabel != null && onAction != null)
              ? SnackBarAction(label: actionLabel, onPressed: onAction)
              : null,
        ),
      );
  }
}

/// Solid error-coloured button for destructive confirms.
class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white)),
      ),
    );
  }
}
