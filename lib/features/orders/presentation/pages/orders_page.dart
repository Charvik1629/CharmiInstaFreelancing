import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Orders (design "Orders"). There is **no `/orders` API** yet
/// (MISSING_APIS #9), so this is a gated shell — the layout is ready and lights
/// up once the endpoint exists. Buying/paying flows into the Payment screens.
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New order',
            onPressed: () => context.push(AppRoutes.createOrder),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: EmptyView(
              title: 'No orders yet',
              subtitle: 'Orders from accepted offers will appear here.',
              icon: Icons.receipt_long_outlined,
              actionLabel: 'See a sample order',
              onAction: () => context.push(AppRoutes.orderDetail),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Orders turn on once the backend endpoint is connected.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.nexveero.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
