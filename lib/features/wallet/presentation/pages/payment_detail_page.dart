import 'package:flutter/material.dart';

import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/wallet_transaction.dart';

/// Payment / transaction details (design "Payment Details", HTML 4814). Renders
/// a [WalletTransaction]: amount, status, ids and date, with Invoice/Receipt
/// actions (gated — no document endpoint yet).
class PaymentDetailPage extends StatelessWidget {
  const PaymentDetailPage({super.key, required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    final tx = transaction;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment details')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: nex.success.withValues(alpha: 0.14),
                child: Icon(Icons.check_circle, color: nex.success, size: 32),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('${tx.isCredit ? '+' : '−'}${tx.amount} credits',
                  style: texts.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: nex.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(tx.isCredit ? 'Credited' : 'Debited',
                    style: TextStyle(
                        color: nex.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: nex.border),
            ),
            child: Column(
              children: [
                _row(context, 'Transaction ID', 'TXN_${tx.id}'),
                if ((tx.reason ?? '').isNotEmpty)
                  _row(context, 'Reason', tx.reason!),
                if (tx.balanceAfter != null)
                  _row(context, 'Balance after', '${tx.balanceAfter}'),
                if (tx.createdAt != null)
                  _row(context, 'Date & time', tx.createdAt!.timeAgo),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Invoice',
                  icon: Icons.receipt_long_outlined,
                  variant: AppButtonVariant.tonal,
                  onPressed: () => AppOverlays.snack(
                      context, 'Invoices arrive once the backend generates them.'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Receipt',
                  icon: Icons.download_outlined,
                  variant: AppButtonVariant.tonal,
                  onPressed: () => AppOverlays.snack(
                      context, 'Receipts arrive once the backend generates them.'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: context.nexveero.textSecondary)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
