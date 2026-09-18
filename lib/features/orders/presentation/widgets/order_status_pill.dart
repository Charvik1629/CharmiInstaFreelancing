import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Coloured status chip shared by the orders list and detail screens.
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final error = Theme.of(context).colorScheme.error;
    final (color, label) = switch (status) {
      'paid' => (nex.success, 'Paid'),
      'completed' => (nex.success, 'Completed'),
      'confirmed' => (nex.info, 'Confirmed'),
      'cancelled' => (error, 'Cancelled'),
      'refunded' => (error, 'Refunded'),
      _ => (nex.warning, 'Pending'),
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
