import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/order.dart';
import '../../domain/orders_repository.dart';
import '../widgets/order_status_pill.dart';

/// Order details (design "Order Details"). Renders a real [AppOrder] passed via
/// route `extra`, and lets the buyer pay (wallet credits) or either party
/// confirm / cancel / complete — all wired to the live `/orders` endpoints.
class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, this.order});

  final AppOrder? order;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late AppOrder? _order = widget.order;
  bool _busy = false;

  int? get _meId => context.read<AuthCubit>().state.user?.id;

  Future<void> _run(Future<Result<AppOrder>> future) async {
    setState(() => _busy = true);
    final result = await future;
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Success(value: final updated):
        setState(() => _order = updated);
      case Err(failure: final f):
        AppOverlays.snack(context, f.message);
    }
  }

  Future<void> _pay(AppOrder o) async {
    final ok = await AppOverlays.confirm(
      context,
      title: 'Pay ${o.amountCredits} credits?',
      message: 'This debits your wallet and credits the seller.',
      confirmLabel: 'Pay',
    );
    if (ok) await _run(sl<OrdersRepository>().payOrder(o.id));
  }

  Future<void> _status(AppOrder o, String status, String confirmLabel,
      String message) async {
    final ok = await AppOverlays.confirm(
      context,
      title: '$confirmLabel?',
      message: message,
      confirmLabel: confirmLabel,
      destructive: status == 'cancelled',
    );
    if (ok) await _run(sl<OrdersRepository>().updateOrderStatus(o.id, status));
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    final o = _order;
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: o == null
          ? const EmptyView(
              title: 'Order not found',
              subtitle: 'Open an order from the Orders list or a chat.',
              icon: Icons.receipt_long_outlined,
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(o.number ?? 'ORD-—',
                        style: texts.bodySmall
                            ?.copyWith(color: nex.textSecondary)),
                    OrderStatusPill(status: o.status),
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
                      if (o.counterparty(_meId) != null)
                        _Line(
                            label: o.buyer?.id == _meId ? 'Seller' : 'Buyer',
                            value: o.counterparty(_meId)!.displayName),
                      if (o.counterparty(_meId) != null)
                        const Divider(height: AppSpacing.xl),
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
                ..._actions(o),
              ],
            ),
    );
  }

  List<Widget> _actions(AppOrder o) {
    final me = _meId;
    final widgets = <Widget>[];
    if (o.canPay(me)) {
      widgets.add(AppButton(
        label: 'Pay ${o.amountCredits} credits',
        icon: Icons.lock_outline,
        isLoading: _busy,
        onPressed: () => _pay(o),
      ));
    }
    if (o.canConfirm(me)) {
      widgets.add(AppButton(
        label: 'Confirm order',
        icon: Icons.check_circle_outline,
        isLoading: _busy,
        onPressed: () => _status(o, 'confirmed', 'Confirm',
            'Confirm this order so the buyer can pay.'),
      ));
    }
    if (o.canComplete(me)) {
      widgets.add(AppButton(
        label: 'Mark completed',
        icon: Icons.done_all,
        variant: AppButtonVariant.tonal,
        isLoading: _busy,
        onPressed: () => _status(
            o, 'completed', 'Complete', 'Mark this order as completed.'),
      ));
    }
    if (o.canCancel(me)) {
      widgets.add(AppButton(
        label: 'Cancel order',
        variant: AppButtonVariant.outline,
        isLoading: _busy,
        onPressed: () => _status(
            o, 'cancelled', 'Cancel order', 'This cancels the order.'),
      ));
    }
    // Space the action buttons evenly.
    return [
      for (var i = 0; i < widgets.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.sm),
        widgets[i],
      ],
    ];
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
