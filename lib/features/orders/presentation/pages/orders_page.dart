import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/order.dart';
import '../cubit/orders_list_cubit.dart';
import '../widgets/order_status_pill.dart';

/// Orders inbox (GET /orders) — buy/sell records settled in credits.
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OrdersListCubit>()..load(),
      child: const _OrdersView(),
    );
  }
}

class _OrdersView extends StatelessWidget {
  const _OrdersView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New order',
            onPressed: () async {
              await context.push(AppRoutes.createOrder);
              if (context.mounted) context.read<OrdersListCubit>().refresh();
            },
          ),
        ],
      ),
      body: BlocBuilder<OrdersListCubit, OrdersListState>(
        builder: (context, state) {
          switch (state.status) {
            case OrdersStatus.initial:
            case OrdersStatus.loading:
              return const LoadingView();
            case OrdersStatus.error:
              return ErrorView(
                message: state.errorMessage ?? 'Could not load orders',
                onRetry: () => context.read<OrdersListCubit>().load(),
              );
            case OrdersStatus.empty:
              return const EmptyView(
                title: 'No orders yet',
                subtitle: 'Orders from accepted offers will appear here.',
                icon: Icons.receipt_long_outlined,
              );
            case OrdersStatus.loaded:
              return RefreshIndicator(
                onRefresh: () => context.read<OrdersListCubit>().refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: state.orders.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) => _OrderTile(order: state.orders[i]),
                ),
              );
          }
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});
  final AppOrder order;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () async {
        await context.push(AppRoutes.orderDetail, extra: order);
        if (context.mounted) context.read<OrdersListCubit>().refresh();
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: nex.elevated,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: nex.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(order.title ?? order.number ?? 'Order',
                      style: texts.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                OrderStatusPill(status: order.status),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.toll, size: 15, color: nex.textSecondary),
                const SizedBox(width: 4),
                Text('${order.amountCredits} credits',
                    style: texts.bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.primary)),
                const Spacer(),
                if (order.createdAt != null)
                  Text(order.createdAt!.timeAgo,
                      style: texts.labelSmall
                          ?.copyWith(color: nex.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
