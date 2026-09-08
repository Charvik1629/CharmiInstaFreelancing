import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Order details (design "Order Details"). Sample layout shown while the
/// `/orders` API is pending (MISSING_APIS #9) — "Pay now" routes to the Payment
/// screen (also gated).
class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _StatusBanner(),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.nexveero.elevated,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lisbon full photo set',
                    style: texts.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text('Order #—  ·  sample',
                    style: TextStyle(color: context.nexveero.textSecondary)),
                const Divider(height: AppSpacing.xl),
                _Line(label: 'Item', value: 'Full photo set'),
                _Line(label: 'Seller', value: 'Maya Kapoor'),
                _Line(label: 'Total payable', value: '₹5,000.00', emphasize: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Pay now',
            onPressed: () => context.push(AppRoutes.paymentMethod),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.nexveero.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top, color: context.nexveero.warning, size: 20),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('Awaiting payment')),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.nexveero.textSecondary)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
