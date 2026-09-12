import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// What the user chose on an overage prompt.
enum OverageChoice { debit, subscribe, cancel }

/// Credit-overage prompt (design "User · overage", HTML 3752/3802). When the
/// wallet can cover [cost] it offers "Debit & create"; otherwise it steers the
/// user to Subscription. One dialog, two states driven by [balance] vs [cost].
class OverageDialog {
  OverageDialog._();

  static Future<OverageChoice> show(
    BuildContext context, {
    required int cost,
    required int balance,
    required String title,
    required String message,
    String debitLabel = 'Debit & create',
  }) async {
    final funded = balance >= cost;
    final result = await showDialog<OverageChoice>(
      context: context,
      builder: (ctx) {
        final nex = ctx.nexveero;
        final scheme = Theme.of(ctx).colorScheme;
        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (funded ? scheme.primary : scheme.error)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(funded ? Icons.payments_outlined : Icons.block,
                      color: funded ? scheme.primary : scheme.error, size: 26),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(title,
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: nex.textSecondary, height: 1.45)),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: nex.elevated,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    children: [
                      _row(ctx, 'Cost', '$cost credits', scheme.primary),
                      const SizedBox(height: 6),
                      _row(ctx, 'Your balance', '$balance', null),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (funded)
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Cancel',
                          variant: AppButtonVariant.outline,
                          onPressed: () =>
                              Navigator.of(ctx).pop(OverageChoice.cancel),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: debitLabel,
                          onPressed: () =>
                              Navigator.of(ctx).pop(OverageChoice.debit),
                        ),
                      ),
                    ],
                  )
                else ...[
                  AppButton(
                    label: 'Go to Subscription',
                    onPressed: () =>
                        Navigator.of(ctx).pop(OverageChoice.subscribe),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(ctx).pop(OverageChoice.cancel),
                    child: const Text('Not now'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
    return result ?? OverageChoice.cancel;
  }

  static Widget _row(BuildContext ctx, String label, String value, Color? c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: ctx.nexveero.textSecondary, fontSize: 12)),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w700, color: c, fontSize: 13)),
      ],
    );
  }
}
