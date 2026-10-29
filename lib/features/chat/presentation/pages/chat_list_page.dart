import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/models/user.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/result.dart';
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
            onPressed: () async {
              await context.push(AppRoutes.manageLabels);
              // Reflect labels created/renamed/deleted there in the filter row.
              if (context.mounted) {
                context.read<ChatListCubit>().reloadLabels();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            tooltip: 'Broadcasts',
            onPressed: () => context.push(AppRoutes.broadcastsList),
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
          const _ChatSearchBar(),
          const _FilterBar(),
          Expanded(
            child: BlocBuilder<ChatListCubit, ChatListState>(
              builder: (context, state) {
                // While searching, surface matching people so a new chat can be
                // started straight from the inbox search.
                if (state.people.isNotEmpty) {
                  return ListView(
                    children: [
                      const _SectionHeader('People'),
                      for (final u in state.people) _PeopleRow(user: u),
                      if (state.conversations.isNotEmpty) ...[
                        const _SectionHeader('Chats'),
                        for (final c in state.conversations)
                          _ConversationTile(conversation: c),
                      ],
                    ],
                  );
                }
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

/// Live search field at the top of the chat list — filters the inbox via
/// GET /chats?q= (peer/group/load title + message bodies), debounced.
class _ChatSearchBar extends StatefulWidget {
  const _ChatSearchBar();

  @override
  State<_ChatSearchBar> createState() => _ChatSearchBarState();
}

class _ChatSearchBarState extends State<_ChatSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return BlocListener<ChatListCubit, ChatListState>(
      listenWhen: (p, c) => p.query != c.query,
      listener: (context, state) {
        // Reflect an external reset (e.g. clearSearch after opening a chat) in
        // the text field.
        if (state.query != _controller.text) _controller.text = state.query;
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
        child: TextField(
          controller: _controller,
          onChanged: (v) => context.read<ChatListCubit>().setSearch(v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search chats',
            prefixIcon: Icon(Icons.search, size: 20, color: nex.iconInactive),
            filled: true,
            fillColor: nex.elevated,
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatListCubit, ChatListState>(
      buildWhen: (p, c) =>
          p.filter != c.filter ||
          p.labels != c.labels ||
          p.labelFilterId != c.labelFilterId,
      builder: (context, state) {
        final cubit = context.read<ChatListCubit>();
        final labelActive = state.labelFilterId != null;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              for (final f in ChatFilter.values) ...[
                AppChip(
                  label: f.label,
                  // A built-in filter is "selected" only when no label filter
                  // is active (a label chip takes over the view).
                  selected: !labelActive && f == state.filter,
                  onTap: () => cubit.setFilter(f),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              // The user's labels become filter chips: tap one to see every
              // chat carrying it; tap again to clear.
              for (final l in state.labels) ...[
                AppChip(
                  label: l.name,
                  icon: Icons.label,
                  selected: state.labelFilterId == l.id,
                  onTap: () => cubit.setLabelFilter(l.id),
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

/// Small uppercase section label ("People" / "Chats") in search results.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
        child: Text(title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.nexveero.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                )),
      );
}

/// A person from the inbox search — tapping starts (or opens) a direct chat.
class _PeopleRow extends StatelessWidget {
  const _PeopleRow({required this.user});
  final User user;

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<ChatListCubit>();
    final result = await AppLoader.run(cubit.startChat(user.id));
    if (!context.mounted) return;
    switch (result) {
      case Success(value: final conv):
        await context.push(AppRoutes.chatThread, extra: conv);
        // Back from the chat → reset the inbox to the plain list.
        if (context.mounted) cubit.clearSearch();
      case Err(failure: final f):
        AppOverlays.snack(context, f.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = user.username != null
        ? '@${user.username}'
        : (user.businessName ?? '');
    return ListTile(
      leading: AppAvatar(
          name: user.name,
          imageUrl: MediaUrl.resolve(user.avatarUrl),
          size: 44),
      title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(Icons.chat_bubble_outline,
          size: 20, color: context.nexveero.textSecondary),
      onTap: () => _open(context),
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
            leading: Icon(conversation.labels.isEmpty
                ? Icons.label_outline
                : Icons.label_off_outlined),
            title: Text(
                conversation.labels.isEmpty ? 'Manage labels' : 'Remove label'),
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
      if (conversation.labels.isEmpty) {
        await _editLabels(context);
      } else {
        // "Remove label" — clear directly, no picker.
        final ok = await cubit.clearLabels(conversation);
        if (context.mounted) {
          AppOverlays.snack(context, ok ? 'Label removed' : 'Could not remove label');
        }
      }
    }
  }

  Future<void> _editLabels(BuildContext context) async {
    final cubit = context.read<ChatListCubit>();
    // Pull the latest labels so any just created on the Manage Labels screen
    // show up here (the cached list can be stale).
    await cubit.reloadLabels();
    if (!context.mounted) return;
    if (cubit.state.labels.isEmpty) {
      AppOverlays.snack(context, 'Create a label first (label icon, top right).');
      return;
    }
    // Use the freshest copy of this conversation (its attached labels may have
    // changed) so the sheet's checkboxes start correct.
    final current = cubit.state.conversations.firstWhere(
      (c) => c.id == conversation.id && c.type == conversation.type,
      orElse: () => conversation,
    );
    await AppOverlays.sheet<void>(
      context,
      builder: (_) => _LabelPickerSheet(
        conversation: current,
        labels: cubit.state.labels,
        onToggle: (label) => cubit.toggleLabel(current, label),
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
        if (!context.mounted) return;
        // Back from a thread: if we were searching, reset the inbox to the
        // plain list (search text + people cleared); otherwise just refresh so
        // this row's unread badge clears (messages were marked read).
        if (cubit.state.query.isNotEmpty || cubit.state.people.isNotEmpty) {
          cubit.clearSearch();
        } else {
          await cubit.refresh();
        }
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
          AppAvatar(
              name: c.title,
              imageUrl: MediaUrl.resolve(c.avatarUrl),
              size: 48,
              enlargeOnTap: true),
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
                            // Capture before the async gap to satisfy the
                            // use_build_context_synchronously lint.
                            final nav = Navigator.of(context);
                            setState(() => _busyId = l.id);
                            final ok = await widget.onToggle(l);
                            if (!mounted) return;
                            if (ok) {
                              nav.pop(); // label applied/removed → close sheet
                              return;
                            }
                            setState(() => _busyId = null);
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
