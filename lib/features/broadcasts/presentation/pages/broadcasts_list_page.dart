import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../admin/presentation/cubit/broadcast_groups_cubit.dart';
import '../../../chat/domain/entities/conversation.dart';
import '../../../chat/domain/repositories/chat_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/broadcast_detail.dart';

/// Broadcasts (design "Broadcast List · quota header + lists · Chats →
/// Broadcasts"): a quota card over the user's broadcast lists, each showing its
/// recipients, newest message and unread count. The + creates a new broadcast.
/// Backed by `GET /broadcasts` via [BroadcastGroupsCubit], whose response
/// carries `meta.broadcast_list_quota` (used / free_limit / period) that the
/// quota card renders live (see [_QuotaCard]).
class BroadcastsListPage extends StatelessWidget {
  const BroadcastsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BroadcastGroupsCubit>()..load(),
      child: const _BroadcastsView(),
    );
  }
}

class _BroadcastsView extends StatelessWidget {
  const _BroadcastsView();

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<BroadcastGroupsCubit>();
    await context.push(AppRoutes.createBroadcast);
    await cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Broadcasts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _create(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const _QuotaCard(),
          Expanded(
            child: BlocBuilder<BroadcastGroupsCubit, BroadcastGroupsState>(
              builder: (context, state) {
                switch (state.status) {
                  case BroadcastGroupsStatus.initial:
                  case BroadcastGroupsStatus.loading:
                    return const LoadingView();
                  case BroadcastGroupsStatus.error:
                    return ErrorView(
                      message: state.errorMessage ?? 'Could not load broadcasts',
                      onRetry: () => context.read<BroadcastGroupsCubit>().load(),
                    );
                  case BroadcastGroupsStatus.empty:
                    return RefreshIndicator(
                      onRefresh: () =>
                          context.read<BroadcastGroupsCubit>().refresh(),
                      child: ListView(children: const [
                        SizedBox(height: 80),
                        EmptyView(
                          title: 'No broadcasts',
                          subtitle:
                              'Send the same message to many people at once — '
                              'create your first broadcast.',
                          icon: Icons.campaign_outlined,
                        ),
                      ]),
                    );
                  case BroadcastGroupsStatus.loaded:
                    return RefreshIndicator(
                      onRefresh: () =>
                          context.read<BroadcastGroupsCubit>().refresh(),
                      child: ListView.builder(
                        itemCount: state.groups.length,
                        itemBuilder: (context, i) =>
                            _BroadcastRow(broadcast: state.groups[i]),
                      ),
                    );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Quota header (design: period + Sent/Remaining + progress + "Send up to N per
/// period"). Driven by `meta.broadcast_list_quota` from GET /broadcasts; when
/// the server omits it, falls back to a plain informational line.
class _QuotaCard extends StatelessWidget {
  const _QuotaCard();

  /// "weekly" → ("This week", "week"); "monthly" → ("This month", "month"); etc.
  static (String, String) _periodLabels(String? period) {
    switch (period) {
      case 'daily':
        return ('Today', 'day');
      case 'weekly':
        return ('This week', 'week');
      case 'monthly':
        return ('This month', 'month');
      default:
        return ('This period', period ?? 'period');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;

    return BlocBuilder<BroadcastGroupsCubit, BroadcastGroupsState>(
      buildWhen: (p, c) => p.quota != c.quota,
      builder: (context, state) {
        final quota = state.quota;
        final (periodTitle, periodUnit) = _periodLabels(quota?.period);
        return Container(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(bottom: BorderSide(color: nex.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(periodTitle,
                      style: texts.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (quota != null && quota.isExempt)
                    Text('Unlimited',
                        style: texts.bodySmall?.copyWith(color: primary)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (quota == null)
                // Server didn't send the quota — keep the card informative.
                Text('Your broadcast allowance for this period.',
                    style: texts.bodyMedium)
              else if (quota.isExempt)
                Text('${quota.used} sent · no limit on this account.',
                    style: texts.bodyMedium)
              else ...[
                Row(
                  children: [
                    _Stat(label: 'Sent', value: '${quota.used}'),
                    const SizedBox(width: AppSpacing.xl),
                    _Stat(label: 'Remaining', value: '${quota.remaining}'),
                    const Spacer(),
                    Text('of ${quota.freeLimit}',
                        style: texts.bodySmall
                            ?.copyWith(color: nex.textSecondary)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: quota.freeLimit > 0
                        ? (quota.used / quota.freeLimit).clamp(0.0, 1.0)
                        : 0,
                    minHeight: 4,
                    backgroundColor: nex.elevated,
                    valueColor: AlwaysStoppedAnimation(primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Send up to ${quota.freeLimit} broadcasts per $periodUnit'
                  '${quota.nextCreditCost > 0 ? ' · then ${quota.nextCreditCost} credits each' : ''}.',
                  style: texts.bodySmall?.copyWith(color: nex.textSecondary),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A compact "N / label" stat pair for the quota header.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: texts.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        Text(label,
            style: texts.labelSmall?.copyWith(color: nex.textSecondary)),
      ],
    );
  }
}

/// One broadcast list row (design: campaign tile + recipient-avatar stack +
/// name + newest message + time + unread badge + recipient count).
class _BroadcastRow extends StatelessWidget {
  const _BroadcastRow({required this.broadcast});
  final BroadcastDetail broadcast;

  Future<void> _open(BuildContext context) async {
    // Open the broadcast chat thread (reuses the chat thread, broadcast type).
    // Broadcasts come from getBroadcasts() — not getChats() — so match there.
    final repo = sl<ChatRepository>();
    final result = await AppLoader.run(repo.getBroadcasts());
    if (!context.mounted) return;
    if (result case Success(value: final convs)) {
      Conversation? match;
      for (final c in convs) {
        if (c.id == broadcast.id && c.type == ConversationType.broadcast) {
          match = c;
          break;
        }
      }
      if (match != null) {
        context.push(AppRoutes.chatThread, extra: match);
        return;
      }
    }
    // Fall back to the broadcast detail if the thread isn't available.
    if (context.mounted) {
      context.push(AppRoutes.broadcastDetail, extra: broadcast.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    final n = broadcast.memberCount;
    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: nex.gradientStart.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.campaign, color: primary, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(broadcast.name,
                            style:
                                texts.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (broadcast.updatedAt != null)
                        Text(broadcast.updatedAt!.timeAgo,
                            style: texts.labelSmall
                                ?.copyWith(color: nex.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('$n ${n == 1 ? 'recipient' : 'recipients'}',
                      style:
                          texts.labelSmall?.copyWith(color: nex.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
