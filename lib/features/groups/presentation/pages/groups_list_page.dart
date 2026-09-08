import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/group.dart';
import '../cubit/groups_list_cubit.dart';

/// Groups (design). The user's groups plus recommended ones to join. Admins also
/// see a headline of total pending join requests across their groups.
class GroupsListPage extends StatelessWidget {
  const GroupsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isManager = context.read<AuthCubit>().state.user?.isAdmin ?? false;
    return BlocProvider(
      create: (_) => sl<GroupsListCubit>()..load(isManager: isManager),
      child: Scaffold(
        appBar: AppBar(title: const Text('Groups')),
        body: BlocBuilder<GroupsListCubit, GroupsListState>(
          builder: (context, state) {
            switch (state.status) {
              case GroupsStatus.loading:
              case GroupsStatus.initial:
                return const LoadingView();
              case GroupsStatus.error:
                return ErrorView(
                  message: state.errorMessage ?? 'Could not load groups',
                  onRetry: () =>
                      context.read<GroupsListCubit>().load(isManager: isManager),
                );
              case GroupsStatus.loaded:
                if (state.isEmpty) {
                  return const EmptyView(
                    title: 'No groups yet',
                    subtitle: 'Join a community to start chatting.',
                    icon: Icons.groups_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      context.read<GroupsListCubit>().refresh(isManager: isManager),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    children: [
                      if (state.pendingJoinTotal > 0)
                        _PendingBanner(total: state.pendingJoinTotal),
                      if (state.myGroups.isNotEmpty) ...[
                        const _SectionLabel('Your groups'),
                        for (final g in state.myGroups) _GroupRow(group: g),
                      ],
                      if (state.recommended.isNotEmpty) ...[
                        const _SectionLabel('Recommended'),
                        for (final g in state.recommended) _GroupRow(group: g),
                      ],
                    ],
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}

/// Admin headline: total pending join requests across all groups. Open a group
/// to review its queue.
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: nex.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: nex.teal.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.how_to_reg_outlined, size: 20, color: nex.teal),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '$total pending join request${total == 1 ? '' : 's'} — '
              'open a group to review.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: Text(label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.nexveero.textSecondary, letterSpacing: 1)),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group});
  final Group group;

  Future<void> _join(BuildContext context) async {
    final ok = await context.read<GroupsListCubit>().join(group);
    if (context.mounted) {
      AppOverlays.snack(context, ok ? 'Join request sent' : 'Could not join');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      leading: AppAvatar(
          name: group.name, imageUrl: MediaUrl.resolve(group.avatarUrl), size: 48),
      title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        group.memberCount != null
            ? '${group.memberCount} members'
            : (group.description ?? ''),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.nexveero.textSecondary),
      ),
      trailing: switch (group.viewerStatus) {
        GroupViewerStatus.member => TextButton(
            onPressed: () => context.push(AppRoutes.groupDetail, extra: group),
            child: const Text('View'),
          ),
        GroupViewerStatus.pending => Text('Pending',
            style: TextStyle(color: context.nexveero.textSecondary)),
        GroupViewerStatus.none => AppButton(
            label: 'Join',
            variant: AppButtonVariant.tonal,
            expanded: false,
            onPressed: () => _join(context),
          ),
      },
      onTap: () => context.push(AppRoutes.groupDetail, extra: group),
    );
  }
}
