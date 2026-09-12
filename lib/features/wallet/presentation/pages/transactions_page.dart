import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../cubit/transactions_cubit.dart';

/// Wallet ledger (design "Transactions"). Credit/debit entries with the running
/// balance, paginated.
class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TransactionsCubit>()..load(),
      child: const _TransactionsView(),
    );
  }
}

class _TransactionsView extends StatefulWidget {
  const _TransactionsView();

  @override
  State<_TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<_TransactionsView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        context.read<TransactionsCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: BlocBuilder<TransactionsCubit, TransactionsState>(
        builder: (context, state) {
          switch (state.status) {
            case TxStatus.loading:
            case TxStatus.initial:
              return const LoadingView();
            case TxStatus.error:
              return ErrorView(
                message: state.errorMessage ?? 'Could not load transactions',
                onRetry: () => context.read<TransactionsCubit>().load(),
              );
            case TxStatus.empty:
              return const EmptyView(
                title: 'No transactions yet',
                subtitle: 'Credits you earn or spend will show up here.',
                icon: Icons.receipt_long_outlined,
              );
            case TxStatus.loaded:
              return RefreshIndicator(
                onRefresh: () => context.read<TransactionsCubit>().refresh(),
                child: ListView.separated(
                  controller: _scroll,
                  itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, indent: 72, color: context.nexveero.border),
                  itemBuilder: (context, i) {
                    if (i >= state.items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _TxRow(tx: state.items[i]);
                  },
                ),
              );
          }
        },
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx});
  final WalletTransaction tx;

  @override
  Widget build(BuildContext context) {
    final green = context.nexveero.success;
    final color = tx.isCredit ? green : Theme.of(context).colorScheme.error;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(tx.isCredit ? Icons.south_west : Icons.north_east,
            color: color, size: 20),
      ),
      title: Text(tx.label),
      subtitle: Text(
        [
          if (tx.createdAt != null) tx.createdAt!.timeAgo,
          if (tx.balanceAfter != null) 'Balance ${tx.balanceAfter}',
        ].join(' · '),
        style: TextStyle(color: context.nexveero.textSecondary),
      ),
      trailing: Text(
        '${tx.isCredit ? '+' : '−'}${tx.amount}',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
      onTap: () => context.push(AppRoutes.paymentDetail, extra: tx),
    );
  }
}
