import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/models/user.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/chat_label.dart';
import '../../domain/entities/conversation.dart';
import '../cubit/chat_list_cubit.dart';
import '../utils/chat_start_helper.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../search/presentation/cubit/search_cubit.dart';

/// The Chats inbox (design section 05). One list for all three chat kinds —
/// direct, group and broadcast — with filter chips to narrow it.
class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state.user?.canChat != true) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Chat, Ask and Offer become available after your account is approved.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return BlocProvider(
          create: (_) => sl<ChatListCubit>()..load(),
          child: const _ChatListView(),
        );
      },
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
            icon: const Icon(Icons.add),
            tooltip: 'Find friends',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const _FindFriendsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Arrange chat filters',
            onPressed: () async {
              final cubit = context.read<ChatListCubit>();
              final order = List<ChatFilter>.of(cubit.state.filterOrder);
              final result = await showModalBottomSheet<List<ChatFilter>>(
                context: context,
                isScrollControlled: true,
                builder: (sheetContext) => StatefulBuilder(
                  builder: (context, update) => SafeArea(
                    child: SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.75,
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Drag to arrange chat filters'),
                          ),
                          Expanded(
                            child: ReorderableListView.builder(
                              itemCount: order.length,
                              onReorderItem: (from, to) => update(() {
                                order.insert(to, order.removeAt(from));
                              }),
                              itemBuilder: (_, i) => ListTile(
                                key: ValueKey(order[i]),
                                title: Text(order[i].label),
                                trailing: const Icon(Icons.drag_handle),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => update(() {
                              order
                                ..clear()
                                ..addAll(ChatFilter.values);
                            }),
                            child: const Text('Restore default order'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(order),
                            child: const Text('Save order'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              if (result != null && !cubit.isClosed) {
                await cubit.reorderFilters(result);
              }
            },
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
          BlocBuilder<ChatListCubit, ChatListState>(
            builder: (context, state) {
              final user = context.read<AuthCubit>().state.user;
              if (user == null ||
                  !user.canChat ||
                  state.filter != ChatFilter.all ||
                  state.query.trim().isNotEmpty ||
                  state.conversations.any((c) => c.isSelf)) {
                return const SizedBox.shrink();
              }
              return ListTile(
                leading: const Icon(Icons.note_alt_outlined),
                title: const Text('You (Notes)'),
                subtitle: const Text('Message yourself'),
                onTap: () async {
                  final cubit = context.read<ChatListCubit>();
                  await startChatWithPinCheck(
                    context,
                    userId: user.id,
                    name: user.name,
                    onSuccess: (conversation) async {
                      await context.push(
                        AppRoutes.chatThread,
                        extra: conversation,
                      );
                      if (!cubit.isClosed) await cubit.refresh();
                    },
                  );
                },
              );
            },
          ),
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
                        itemBuilder: (context, i) => _ConversationTile(
                          conversation: state.conversations[i],
                        ),
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
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
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
          p.labelFilterId != c.labelFilterId ||
          p.filterOrder != c.filterOrder,
      builder: (context, state) {
        final cubit = context.read<ChatListCubit>();
        final labelActive = state.labelFilterId != null;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              for (final f in state.filterOrder) ...[
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
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.xs,
    ),
    child: Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.nexveero.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
  );
}

/// A person from the inbox search — tapping starts (or opens) a direct chat.
class _PeopleRow extends StatelessWidget {
  const _PeopleRow({required this.user});
  final User user;

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<ChatListCubit>();
    await startChatWithPinCheck(
      context,
      userId: user.id,
      name: user.name,
      avatarUrl: user.avatarUrl,
      onSuccess: (conv) async {
        await context.push(AppRoutes.chatThread, extra: conv);
        // Back from the chat → reset the inbox to the plain list.
        if (context.mounted) cubit.clearSearch();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if ((user.businessName ?? '').isNotEmpty) user.businessName!,
      if (user.username != null) '@${user.username}',
    ].join(' · ');
    return ListTile(
      leading: AppAvatar(
        name: user.name,
        imageUrl: MediaUrl.resolve(user.avatarUrl),
        size: 44,
      ),
      title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(
        Icons.chat_bubble_outline,
        size: 20,
        color: context.nexveero.textSecondary,
      ),
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
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete chat'),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
          ListTile(
            leading: Icon(
              conversation.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            title: Text(conversation.isPinned ? 'Unpin chat' : 'Pin chat'),
            onTap: () => Navigator.of(ctx).pop('pin'),
          ),
          ListTile(
            leading: Icon(
              conversation.labels.isEmpty
                  ? Icons.label_outline
                  : Icons.label_off_outlined,
            ),
            title: Text(
              conversation.labels.isEmpty ? 'Manage labels' : 'Remove label',
            ),
            onTap: () => Navigator.of(ctx).pop('labels'),
          ),
        ],
      ),
    );
    if (action == 'delete' && context.mounted) {
      final confirmed = await AppOverlays.confirm(
        context,
        title: 'Delete this chat?',
        message: 'This removes the chat and its history for you. Other participants keep their messages.',
        confirmLabel: 'Delete for me',
        destructive: true,
      );
      if (confirmed && context.mounted) {
        final result = await cubit.deleteChat(conversation.id);
        if (context.mounted && !result.isSuccess) {
          AppOverlays.snack(
            context,
            result.failureOrNull?.message ?? 'Could not delete chat',
          );
        }
      }
    } else if (action == 'pin') {
      final r = await cubit.togglePin(conversation);
      if (context.mounted && !r.isSuccess) {
        AppOverlays.snack(
          context,
          r.failureOrNull?.message ?? 'Could not update pin',
        );
      }
    } else if (action == 'labels' && context.mounted) {
      if (conversation.labels.isEmpty) {
        await _editLabels(context);
      } else {
        // "Remove label" — clear directly, no picker.
        final ok = await cubit.clearLabels(conversation);
        if (context.mounted) {
          AppOverlays.snack(
            context,
            ok ? 'Label removed' : 'Could not remove label',
          );
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
      AppOverlays.snack(
        context,
        'Create a label first (label icon, top right).',
      );
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
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: _Leading(conversation: c),
      title: Row(
        children: [
          if (c.isPinned) ...[
            Icon(
              Icons.push_pin,
              size: 13,
              color: context.nexveero.textSecondary,
            ),
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
                    color: l.colorValue(Theme.of(context).colorScheme.primary),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ],
      ),
      subtitle: Text(
        [
          if ((c.subtitle ?? '').isNotEmpty) c.subtitle!,
          c.lastMessage ?? 'No messages yet',
        ].join(' · '),
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
            Text(
              c.lastMessageAt!.timeAgo,
              style: texts.labelSmall?.copyWith(
                color: context.nexveero.textSecondary,
              ),
            ),
          const SizedBox(height: 4),
          if (c.hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                gradient: context.nexveero.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '${c.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
            enlargeOnTap: true,
          ),
          if (badge != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
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
        Text(
          'Labels for ${widget.conversation.title}',
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
                          Theme.of(context).colorScheme.primary,
                        ),
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

class _FindFriendsPage extends StatelessWidget {
  const _FindFriendsPage();
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<SearchCubit>(),
    child: Scaffold(
      appBar: AppBar(title: const Text('Find friends')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Builder(
              builder: (context) => TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by name or number…',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: context.read<SearchCubit>().onQueryChanged,
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<SearchCubit, SearchState>(
              builder: (context, state) {
                if (state.status == SearchStatus.searching) {
                  return const LoadingView();
                }
                if (state.status == SearchStatus.error) {
                  return Center(
                    child: Text(state.errorMessage ?? 'Could not find people'),
                  );
                }
                if (state.results.isEmpty) {
                  return Center(
                    child: Text(
                      state.query.trim().length < 2
                          ? 'Enter a name or phone number to find friends.'
                          : 'No matching people.',
                    ),
                  );
                }
                return ListView(
                  children: [
                    for (final user in state.results)
                      ListTile(
                        leading: AppAvatar(
                          name: user.name,
                          imageUrl: MediaUrl.resolve(user.avatarUrl),
                        ),
                        title: Text(user.name),
                        subtitle: Text(user.businessName ?? ''),
                        trailing: const Icon(Icons.chat_bubble_outline),
                        onTap: () => startChatWithPinCheck(
                          context,
                          userId: user.id,
                          name: user.name,
                          avatarUrl: user.avatarUrl,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
