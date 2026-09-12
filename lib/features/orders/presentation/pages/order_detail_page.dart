import 'package:flutter/material.dart';

import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/order.dart';

/// Order details (design "Order Details", HTML 4603). Renders a real [AppOrder]
/// passed via route `extra` (from creation). Amount is shown in credits — the
/// API settles orders in credits, not cash. A "Pay" action awaits a backend pay
/// endpoint (not in the current docs).
class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key, this.order});

  final AppOrder? order;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    final o = order;
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: o == null
          ? const EmptyView(
              title: 'Order not found',
              subtitle:
                  'Open an order from a chat. A shareable order list arrives once '
                  'the backend exposes GET /orders.',
              icon: Icons.receipt_long_outlined,
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(o.number ?? 'ORD-—',
                        style: texts.bodySmall?.copyWith(
                            color: nex.textSecondary,
                            fontFeatures: const [])),
                    _StatusPill(status: o.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if ((o.title ?? '').isNotEmpty)
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.title!, style: texts.titleMedium),
                        if ((o.notes ?? '').isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(o.notes!,
                              style: TextStyle(color: nex.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                _Card(
                  child: Column(
                    children: [
                      _Line(label: 'Amount', value: '${o.amountCredits} credits'),
                      const Divider(height: AppSpacing.xl),
                      _Line(
                        label: 'Total payable',
                        value: '${o.amountCredits} credits',
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
                if (o.createdAt != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Created ${o.createdAt!.timeAgo}',
                      style: texts.labelSmall
                          ?.copyWith(color: nex.textSecondary)),
                ],
                const SizedBox(height: AppSpacing.xl),
                if (o.status == 'pending')
                  AppButton(
                    label: 'Pay ${o.amountCredits} credits',
                    icon: Icons.lock_outline,
                    onPressed: () => AppOverlays.snack(context,
                        'Order payment is settled by the backend once its pay endpoint is live.'),
                  ),
              ],
            ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final (color, label) = switch (status) {
      'paid' || 'completed' => (nex.success, 'Paid'),
      'in_progress' => (nex.info, 'In progress'),
      'cancelled' => (Theme.of(context).colorScheme.error, 'Cancelled'),
      _ => (nex.warning, 'Awaiting payment'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.nexveero.border),
      ),
      child: child,
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: context.nexveero.textSecondary)),
        Text(value,
            style: emphasize
                ? style?.copyWith(color: Theme.of(context).colorScheme.primary)
                : style),
      ],
    );
  }
}
