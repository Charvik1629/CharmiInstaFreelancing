import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/chat_label.dart';
import '../../domain/entities/conversation.dart';
import '../cubit/chat_list_cubit.dart';

/// The Chats inbox (design section 05). One list for all three chat kinds —
/// direct, group and broadcast — with filter chips to narrow it.
class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChatListCubit>()..load(),
      child: const _ChatListView(),
    );
  }
}

class _ChatListView extends StatelessWidget {
  const _ChatListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.star_border),
            tooltip: 'Starred messages',
            onPressed: () => context.push(AppRoutes.starredMessages),
          ),
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'Manage labels',
            onPressed: () => context.push(AppRoutes.manageLabels),
          ),
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            tooltip: 'New broadcast',
            onPressed: () => context.push(AppRoutes.createBroadcast),
          ),
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'Groups',
            onPressed: () => context.push(AppRoutes.groups),
          ),
        ],
      ),
      body: Column(
        children: [
          const _FilterBar(),
          const _LabelFilterBar(),
          Expanded(
            child: BlocBuilder<ChatListCubit, ChatListState>(
              builder: (context, state) {
                switch (state.status) {
                  case ChatListStatus.loading:
                  case ChatListStatus.initial:
                    return const ListSkeleton();
                  case ChatListStatus.error:
                    return ErrorView(
                      message: state.errorMessage ?? 'Could not load chats',
                      onRetry: () => context.read<ChatListCubit>().load(),
                    );
                  case ChatListStatus.empty:
                    return const EmptyView(
                      title: 'No chats yet',
                      subtitle: 'Your conversations will appear here.',
                    );
                  case ChatListStatus.loaded:
                    return RefreshIndicator(
                      onRefresh: () => context.read<ChatListCubit>().refresh(),
                      child: ListView.separated(
                        itemCount: state.conversations.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          indent: 76,
                          color: context.nexveero.border,
                        ),
                        itemBuilder: (context, i) =>
                            _ConversationTile(conversation: state.conversations[i]),
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

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatListCubit, ChatListState>(
      buildWhen: (p, c) => p.filter != c.filter,
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              for (final f in ChatFilter.values) ...[
                AppChip(
                  label: f.label,
                  selected: f == state.filter,
                  onTap: () => context.read<ChatListCubit>().setFilter(f),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Horizontal row of the user's labels; tapping one filters the inbox to chats
/// carrying it (client-side). Hidden when the user has no labels.
class _LabelFilterBar extends StatelessWidget {
  const _LabelFilterBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatListCubit, ChatListState>(
      buildWhen: (p, c) =>
          p.labels != c.labels || p.labelFilterId != c.labelFilterId,
      builder: (context, state) {
        if (state.labels.isEmpty) return const SizedBox.shrink();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(
              left: AppSpacing.lg, right: AppSpacing.lg, bottom: AppSpacing.sm),
          child: Row(
            children: [
              AppChip(
                label: 'All',
                selected: state.labelFilterId == null,
                onTap: () => context.read<ChatListCubit>().setLabelFilter(null),
              ),
              const SizedBox(width: AppSpacing.sm),
              for (final l in state.labels) ...[
                AppChip(
                  label: l.name,
                  selected: state.labelFilterId == l.id,
                  onTap: () =>
                      context.read<ChatListCubit>().setLabelFilter(l.id),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  Future<void> _openMenu(BuildContext context) async {
    final cubit = context.read<ChatListCubit>();
    final action = await AppOverlays.sheet<String>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(conversation.isPinned
                ? Icons.push_pin
                : Icons.push_pin_outlined),
            title: Text(conversation.isPinned ? 'Unpin chat' : 'Pin chat'),
            onTap: () => Navigator.of(ctx).pop('pin'),
          ),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Manage labels'),
            onTap: () => Navigator.of(ctx).pop('labels'),
          ),
        ],
      ),
    );
    if (action == 'pin') {
      final r = await cubit.togglePin(conversation);
      if (context.mounted && !r.isSuccess) {
        AppOverlays.snack(
            context, r.failureOrNull?.message ?? 'Could not update pin');
      }
    } else if (action == 'labels' && context.mounted) {
      await _editLabels(context);
    }
  }

  Future<void> _editLabels(BuildContext context) async {
    final cubit = context.read<ChatListCubit>();
    if (cubit.state.labels.isEmpty) {
      AppOverlays.snack(context, 'Create a label first (label icon, top right).');
      return;
    }
    await AppOverlays.sheet<void>(
      context,
      builder: (_) => _LabelPickerSheet(
        conversation: conversation,
        labels: cubit.state.labels,
        onToggle: (label) => cubit.toggleLabel(conversation, label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final c = conversation;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      leading: _Leading(conversation: c),
      title: Row(
        children: [
          if (c.isPinned) ...[
            Icon(Icons.push_pin, size: 13, color: context.nexveero.textSecondary),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (c.labels.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.xs),
            for (final l in c.labels.take(3))
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: l.colorValue(
                        Theme.of(context).colorScheme.primary),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ],
      ),
      subtitle: Text(
        c.lastMessage ?? (c.subtitle ?? 'No messages yet'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: texts.bodySmall?.copyWith(
          color: context.nexveero.textSecondary,
          fontWeight: c.hasUnread ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      onLongPress: c.isBroadcast ? null : () => _openMenu(context),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (c.lastMessageAt != null)
            Text(c.lastMessageAt!.timeAgo,
                style: texts.labelSmall?.copyWith(color: context.nexveero.textSecondary)),
          const SizedBox(height: 4),
          if (c.hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                gradient: context.nexveero.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('${c.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      onTap: () async {
        final cubit = context.read<ChatListCubit>();
        await context.push(AppRoutes.chatThread, extra: c);
        // Returning from a thread: the messages were marked read, so refresh
        // the inbox to clear this row's unread badge.
        await cubit.refresh();
      },
    );
  }
}

/// Avatar with a small badge marking group / broadcast threads.
class _Leading extends StatelessWidget {
  const _Leading({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final badge = switch (c.type) {
      ConversationType.group => Icons.groups,
      ConversationType.broadcast => Icons.campaign,
      ConversationType.direct => null,
    };
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          AppAvatar(name: c.title, imageUrl: MediaUrl.resolve(c.avatarUrl), size: 48),
          if (badge != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
                child: Icon(badge, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet to attach/detach labels on a conversation. Toggling calls
/// [onToggle] (which hits the API + reloads the list) and updates locally.
class _LabelPickerSheet extends StatefulWidget {
  const _LabelPickerSheet({
    required this.conversation,
    required this.labels,
    required this.onToggle,
  });

  final Conversation conversation;
  final List<ChatLabel> labels;
  final Future<bool> Function(ChatLabel) onToggle;

  @override
  State<_LabelPickerSheet> createState() => _LabelPickerSheetState();
}

class _LabelPickerSheetState extends State<_LabelPickerSheet> {
  late final Set<int> _attached = {
    for (final l in widget.conversation.labels) l.id,
  };
  int? _busyId;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Labels for ${widget.conversation.title}',
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final l in widget.labels)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: l.colorValue(
                            Theme.of(context).colorScheme.primary),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(l.name),
                    value: _attached.contains(l.id),
                    onChanged: _busyId != null
                        ? null
                        : (_) async {
                            setState(() => _busyId = l.id);
                            final ok = await widget.onToggle(l);
                            if (!mounted) return;
                            setState(() {
                              if (ok) {
                                if (_attached.contains(l.id)) {
                                  _attached.remove(l.id);
                                } else {
                                  _attached.add(l.id);
                                }
                              }
                              _busyId = null;
                            });
                          },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
