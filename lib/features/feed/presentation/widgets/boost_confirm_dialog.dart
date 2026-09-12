import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Boost confirmation (design "Boost confirm", HTML 1972–1996): title +
/// subtitle, a Duration / Cost / Your balance breakdown card, then a
/// `Cancel | 🚀 Boost` row. Returns true when the user confirms.
class BoostConfirmDialog extends StatelessWidget {
  const BoostConfirmDialog({
    super.key,
    required this.cost,
    required this.balance,
    this.durationHours = 24,
  });

  final int cost;
  final int balance;
  final int durationHours;

  static Future<bool> show(
    BuildContext context, {
    required int cost,
    required int balance,
    int durationHours = 24,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => BoostConfirmDialog(
        cost: cost,
        balance: balance,
        durationHours: durationHours,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Boost post', style: texts.titleLarge)),
                InkResponse(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Icon(Icons.close, size: 20, color: nex.iconInactive),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Feature this post at the top of the feed',
                style: texts.bodyMedium?.copyWith(color: nex.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: nex.elevated,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: nex.border),
              ),
              child: Column(
                children: [
                  _Row(label: 'Duration', value: '$durationHours hours'),
                  const SizedBox(height: AppSpacing.md),
                  _Row(
                    label: 'Cost',
                    value: '$cost credits',
                    valueColor: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Row(label: 'Your balance', value: '$balance'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.outline,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: 'Boost',
                    icon: Icons.rocket_launch,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: nex.textSecondary)),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: valueColor)),
      ],
    );
  }
}
