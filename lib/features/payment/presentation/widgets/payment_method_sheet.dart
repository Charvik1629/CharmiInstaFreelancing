import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// How the buyer pays for credits.
enum PaymentMethod { razorpay, inAppPurchase }

/// Bottom-sheet chooser offering both Razorpay (card/UPI/netbanking) and the
/// platform store's in-app purchase. Returns the chosen method, or null.
class PaymentMethodSheet {
  PaymentMethodSheet._();

  static Future<PaymentMethod?> show(BuildContext context) {
    return showModalBottomSheet<PaymentMethod>(
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
                  child: Text('Choose payment method',
                      style: Theme.of(ctx).textTheme.titleLarge),
                ),
                _MethodRow(
                  icon: Icons.credit_card,
                  title: 'Card / UPI / Netbanking',
                  subtitle: 'Pay securely with Razorpay',
                  onTap: () => Navigator.of(ctx).pop(PaymentMethod.razorpay),
                ),
                _MethodRow(
                  icon: Icons.apple,
                  title: 'In-app purchase',
                  subtitle: 'Pay via the App Store / Play Store',
                  onTap: () =>
                      Navigator.of(ctx).pop(PaymentMethod.inAppPurchase),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: nex.elevated,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(color: nex.textSecondary, fontSize: 12)),
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
