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
import '../../../chat/domain/entities/conversation.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_join_request.dart';
import '../cubit/group_detail_cubit.dart';

/// Group details (design "Chat / Group Details"): avatar, name, description,
/// member list, and Join / Cancel / Leave / Open chat actions. Admins also see a
/// pending join-requests queue (approve/decline) and can remove members.
class GroupDetailPage extends StatelessWidget {
  const GroupDetailPage({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final isManager = context.read<AuthCubit>().state.user?.isAdmin ?? false;
    return BlocProvider(
      create: (_) =>
          sl<GroupDetailCubit>(param1: group.id)..load(isManager: isManager),
      child: _GroupDetailView(fallback: group),
    );
  }
}

class _GroupDetailView extends StatelessWidget {
  const _GroupDetailView({required this.fallback});
  final Group fallback;

  void _openChat(BuildContext context, Group group) {
    if (group.conversationId == null) return;
    context.push(
      AppRoutes.chatThread,
      extra: Conversation(
        id: group.conversationId!,
        type: ConversationType.group,
        title: group.name,
        avatarUrl: group.avatarUrl,
      ),
    );
  }

  Future<void> _requestJoin(BuildContext context) async {
    final ok = await context.read<GroupDetailCubit>().requestJoin();
    if (context.mounted) {
      AppOverlays.snack(context, ok ? 'Join request sent' : 'Could not join');
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final ok = await context.read<GroupDetailCubit>().cancelRequest();
    if (context.mounted) {
      AppOverlays.snack(context, ok ? 'Request cancelled' : 'Could not cancel');
    }
  }

  Future<void> _leave(BuildContext context) async {
    final confirmed = await AppOverlays.confirm(
      context,
      title: 'Leave group?',
      message: 'You will stop receiving this group\'s messages.',
      confirmLabel: 'Leave',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await context.read<GroupDetailCubit>().leave();
    if (context.mounted) {
      AppOverlays.snack(context, ok ? 'Left group' : 'Could not leave');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group info')),
      body: BlocConsumer<GroupDetailCubit, GroupDetailState>(
        listenWhen: (p, c) =>
            p.errorMessage != c.errorMessage && c.errorMessage != null,
        listener: (context, state) =>
            AppOverlays.snack(context, state.errorMessage!),
        builder: (context, state) {
          if (state.status == DetailStatus.loading ||
              state.status == DetailStatus.initial) {
            return const LoadingView();
          }
          if (state.status == DetailStatus.error) {
            return ErrorView(
              message: state.errorMessage ?? 'Could not load group',
              onRetry: () => context.read<GroupDetailCubit>().load(),
            );
          }
          final group = state.group ?? fallback;
          final texts = Theme.of(context).textTheme;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Center(
                child: Column(
                  children: [
                    AppAvatar(
                        name: group.name,
                        imageUrl: MediaUrl.resolve(group.avatarUrl),
                        size: 88),
                    const SizedBox(height: AppSpacing.md),
                    Text(group.name, style: texts.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (group.memberCount != null)
                          '${group.memberCount} members',
                        if (group.isPrivate) 'Private',
                      ].join(' · '),
                      style: texts.bodySmall
                          ?.copyWith(color: context.nexveero.textSecondary),
                    ),
                    if ((group.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(group.description!, textAlign: TextAlign.center),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _actions(context, group),
              if (state.isManager && state.joinRequests.isNotEmpty)
                _JoinRequests(
                  requests: state.joinRequests,
                  actingOnId: state.actingOnId,
                ),
              if (state.members.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text('MEMBERS · ${state.members.length}',
                    style: texts.labelSmall?.copyWith(
                        color: context.nexveero.textSecondary, letterSpacing: 1)),
                const SizedBox(height: AppSpacing.sm),
                for (final m in state.members)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AppAvatar(
                        name: m.name,
                        imageUrl: MediaUrl.resolve(m.avatarUrl),
                        size: 40),
                    title: Text(m.name),
                    trailing: _memberTrailing(context, state, m),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _actions(BuildContext context, Group group) {
    if (group.isMember) {
      return Column(
        children: [
          if (group.canChat)
            AppButton(
              label: 'Open chat',
              icon: Icons.chat_bubble_outline,
              onPressed: () => _openChat(context, group),
            ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Leave group',
            variant: AppButtonVariant.outline,
            onPressed: () => _leave(context),
          ),
        ],
      );
    }
    if (group.isPending) {
      return AppButton(
        label: 'Cancel request',
        variant: AppButtonVariant.outline,
        onPressed: () => _cancel(context),
      );
    }
    return AppButton(
        label: 'Request to join', onPressed: () => _requestJoin(context));
  }

  Widget? _memberTrailing(
      BuildContext context, GroupDetailState state, GroupMember m) {
    if (state.isManager && m.role != 'owner' && m.role != 'admin') {
      return IconButton(
        icon: const Icon(Icons.person_remove_outlined, size: 20),
        tooltip: 'Remove',
        color: Theme.of(context).colorScheme.error,
        onPressed: () async {
          final ok = await AppOverlays.confirm(
            context,
            title: 'Remove member?',
            message: '${m.name} will be removed from the group.',
            confirmLabel: 'Remove',
            destructive: true,
          );
          if (ok && context.mounted) {
            await context.read<GroupDetailCubit>().removeMember(m);
          }
        },
      );
    }
    if (m.role != null && m.role != 'member') {
      return Text(m.role!,
          style: TextStyle(color: context.nexveero.textSecondary));
    }
    return null;
  }
}

class _JoinRequests extends StatelessWidget {
  const _JoinRequests({required this.requests, required this.actingOnId});
  final List<GroupJoinRequest> requests;
  final int? actingOnId;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Text('JOIN REQUESTS · ${requests.length}',
            style: texts.labelSmall?.copyWith(
                color: context.nexveero.textSecondary, letterSpacing: 1)),
        const SizedBox(height: AppSpacing.sm),
        for (final r in requests)
          _RequestRow(request: r, busy: actingOnId == r.id),
      ],
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request, required this.busy});
  final GroupJoinRequest request;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final name = request.user?.name ?? 'User #${request.user?.id ?? '?'}';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.nexveero.border),
      ),
      child: Row(
        children: [
          AppAvatar(
              name: name,
              imageUrl: MediaUrl.resolve(request.user?.avatarUrl),
              size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(name,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            IconButton(
              icon: Icon(Icons.check_circle_outline,
                  color: context.nexveero.success),
              tooltip: 'Approve',
              onPressed: () =>
                  context.read<GroupDetailCubit>().approveRequest(request),
            ),
            IconButton(
              icon: Icon(Icons.cancel_outlined,
                  color: Theme.of(context).colorScheme.error),
              tooltip: 'Decline',
              onPressed: () =>
                  context.read<GroupDetailCubit>().declineRequest(request),
            ),
          ],
        ],
      ),
    );
  }
}
