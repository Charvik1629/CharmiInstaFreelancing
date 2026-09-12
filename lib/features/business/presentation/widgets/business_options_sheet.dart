import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Owner's "Business ⋯" menu (design "Business ⋯ menu", HTML 1251–1318):
/// a bottom sheet titled BUSINESS OPTIONS with Edit post / Boost post rows and
/// a Cancel pill. Returns `'edit'`, `'boost'`, or null.
enum BusinessOption { edit, boost }

class BusinessOptionsSheet {
  BusinessOptionsSheet._();

  static Future<BusinessOption?> show(
    BuildContext context, {
    int boostCost = 20,
    int boostHours = 24,
  }) {
    return showModalBottomSheet<BusinessOption>(
      context: context,
      builder: (ctx) {
        final nex = ctx.nexveero;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                0, AppSpacing.sm, 0, AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: nex.border,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                  child: Text('BUSINESS OPTIONS',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: nex.textSecondary)),
                ),
                _OptionRow(
                  icon: Icons.edit_outlined,
                  tint: nex.gradientStart,
                  title: 'Edit post',
                  subtitle: 'Update photos, caption, or details',
                  onTap: () => Navigator.of(ctx).pop(BusinessOption.edit),
                ),
                Divider(height: 1, indent: AppSpacing.lg, endIndent: AppSpacing.lg, color: nex.border),
                _OptionRow(
                  icon: Icons.rocket_launch,
                  tint: nex.gradientEnd,
                  title: 'Boost post',
                  subtitle: '$boostCost credits · featured for ${boostHours}h',
                  onTap: () => Navigator.of(ctx).pop(BusinessOption.boost),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        side: BorderSide(color: nex.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 22, color: tint),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: nex.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: nex.iconInactive),
          ],
        ),
      ),
    );
  }
}
