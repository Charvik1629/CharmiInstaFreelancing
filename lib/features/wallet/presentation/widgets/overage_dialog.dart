import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// What the user chose on an overage prompt.
enum OverageChoice { debit, subscribe, cancel }

/// Broadcast credit-overage prompt (design "User · Message overage" /
/// "Chat list overage", HTML 3752/3804). Two states driven by [balance] vs
/// [cost]:
///
/// - Funded ([balance] >= [cost]) → "Free … limit reached": a payments icon
///   tile, a boxed Cost/Your balance row, and Cancel (outline) + [debitLabel]
///   (gradient) side by side.
/// - Unfunded → "… limit over": a red block icon tile, a single "Need N ·
///   Wallet has X" pill, and full-width Go to Subscription (gradient) + Not now
///   (tonal).
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
        final accent = funded ? scheme.primary : scheme.error;
        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rounded-square tinted icon tile (design 48x48, r14).
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(funded ? Icons.payments : Icons.block,
                      color: accent, size: 26),
                ),
                const SizedBox(height: 14),
                Text(title,
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                Text(message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: nex.textSecondary, fontSize: 12, height: 1.45)),
                const SizedBox(height: 14),
                if (funded) ...[
                  // Boxed Cost / Your balance rows.
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: nex.elevated,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: nex.border),
                    ),
                    child: Column(
                      children: [
                        _row(ctx, 'Cost', '$cost credits', scheme.primary),
                        const SizedBox(height: AppSpacing.sm),
                        _row(ctx, 'Your balance', '$balance', null),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        flex: 10,
                        child: AppButton(
                          label: 'Cancel',
                          variant: AppButtonVariant.outline,
                          onPressed: () =>
                              Navigator.of(ctx).pop(OverageChoice.cancel),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 13,
                        child: AppButton(
                          label: debitLabel,
                          onPressed: () =>
                              Navigator.of(ctx).pop(OverageChoice.debit),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // "Need N credits · Wallet has X" pill.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 10),
                    decoration: BoxDecoration(
                      color: nex.elevated,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                            color: nex.textSecondary, fontSize: 11),
                        children: [
                          const TextSpan(text: 'Need '),
                          TextSpan(
                            text: '$cost credits',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary),
                          ),
                          const TextSpan(text: ' · Wallet has '),
                          TextSpan(
                            text: '$balance',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Go to Subscription',
                    onPressed: () =>
                        Navigator.of(ctx).pop(OverageChoice.subscribe),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Not now',
                    variant: AppButtonVariant.tonal,
                    onPressed: () =>
                        Navigator.of(ctx).pop(OverageChoice.cancel),
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
            style:
                TextStyle(fontWeight: FontWeight.w700, color: c, fontSize: 13)),
      ],
    );
  }
}
