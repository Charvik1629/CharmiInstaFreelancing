import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../broadcasts/domain/broadcast_detail.dart';
import '../cubit/broadcast_groups_cubit.dart';

/// Admin · Broadcast groups (design "Admin · Broadcast groups", HTML 3862/3899).
/// Reusable recipient groups admins target with broadcasts, backed by
/// GET /broadcasts via [BroadcastGroupsCubit].
class AdminBroadcastGroupsPage extends StatelessWidget {
  const AdminBroadcastGroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BroadcastGroupsCubit>()..load(),
      child: const _BroadcastGroupsView(),
    );
  }
}

class _BroadcastGroupsView extends StatelessWidget {
  const _BroadcastGroupsView();

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<BroadcastGroupsCubit>();
    await context.push(AppRoutes.createBroadcastGroup);
    // A newly created group won't be in the list yet, so always refresh on return.
    await cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<BroadcastGroupsCubit, BroadcastGroupsState>(
          buildWhen: (p, c) => p.groups.length != c.groups.length,
          builder: (context, state) {
            final n = state.groups.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Broadcast groups'),
                Text(
                  'Admin only · $n ${n == 1 ? 'group' : 'groups'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.nexveero.gradientStart,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New group',
            onPressed: () => _create(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: AppTextField(
              hint: 'Search groups',
              prefixIcon: Icons.search,
              onChanged: (v) => context.read<BroadcastGroupsCubit>().search(v),
            ),
          ),
          Expanded(
            child: BlocBuilder<BroadcastGroupsCubit, BroadcastGroupsState>(
              builder: (context, state) {
                switch (state.status) {
                  case BroadcastGroupsStatus.initial:
                  case BroadcastGroupsStatus.loading:
                    return const LoadingView();
                  case BroadcastGroupsStatus.error:
                    return ErrorView(
                      message: state.errorMessage ?? 'Could not load groups',
                      onRetry: () => context.read<BroadcastGroupsCubit>().load(),
                    );
                  case BroadcastGroupsStatus.empty:
                    return RefreshIndicator(
                      onRefresh: () =>
                          context.read<BroadcastGroupsCubit>().refresh(),
                      child: ListView(
                        children: [
                          const SizedBox(height: 80),
                          EmptyView(
                            title: 'No broadcast groups',
                            subtitle: state.query.trim().isEmpty
                                ? 'Create an official broadcast group to send announcements to members.'
                                : 'No groups match “${state.query.trim()}”.',
                            icon: Icons.campaign_outlined,
                            actionLabel: state.query.trim().isEmpty
                                ? 'Create group'
                                : null,
                            onAction: state.query.trim().isEmpty
                                ? () => _create(context)
                                : null,
                          ),
                        ],
                      ),
                    );
                  case BroadcastGroupsStatus.loaded:
                    return RefreshIndicator(
                      onRefresh: () =>
                          context.read<BroadcastGroupsCubit>().refresh(),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                            AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
                        itemCount: state.groups.length,
                        itemBuilder: (context, i) =>
                            _GroupCard(group: state.groups[i]),
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

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});
  final BroadcastDetail group;

  Future<void> _edit(BuildContext context) async {
    final cubit = context.read<BroadcastGroupsCubit>();
    await context.push(AppRoutes.createBroadcastGroup, extra: group);
    await cubit.refresh(); // reflect edits on return
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<BroadcastGroupsCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group'),
        content: Text('Delete “${group.name}”? This can’t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await cubit.delete(group);
    if (deleted && context.mounted) {
      AppOverlays.snack(context, 'Group deleted');
    } else if (context.mounted) {
      AppOverlays.snack(context, 'Could not delete group');
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final nexveero = context.nexveero;
    final n = group.memberCount;
    final meta = [
      '$n ${n == 1 ? 'member' : 'members'}',
      if (group.updatedAt != null) 'Updated ${group.updatedAt!.timeAgo}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: nexveero.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  gradient: nexveero.primaryGradient,
                ),
                child: const Icon(Icons.campaign, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name,
                        style: texts.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if ((group.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(group.description!,
                          style: texts.bodySmall
                              ?.copyWith(color: nexveero.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(meta,
                        style: texts.labelSmall
                            ?.copyWith(color: nexveero.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.outline,
                  onPressed: () => _edit(context),
                ),
              ),
              if (group.canDelete) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    variant: AppButtonVariant.outline,
                    onPressed: () => _confirmDelete(context),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
