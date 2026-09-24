import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/user.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../chat/domain/repositories/chat_repository.dart';
import '../cubit/search_cubit.dart';

/// People search (design "Search"): a search field, a RECENT list when empty,
/// and RESULTS as you type. Content/post search awaits an API text query
/// (MISSING_APIS "Search") — this searches people via GET /users?q=.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SearchCubit>(),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Repaint the accent focus border as the field gains/loses focus.
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final focused = _focus.hasFocus;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        // Taller bar so the search field has comfortable padding.
        toolbarHeight: 72,
        title: Padding(
          // Design: full-width bar with a side gutter (padding 8 20 12).
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, 0),
          child: Container(
            decoration: BoxDecoration(
              color: context.nexveero.elevated,
              // Design: rounded-12 field (not a pill), 1.5px accent border on
              // focus, subtle border otherwise.
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: focused ? primary : context.nexveero.border,
                width: focused ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.search,
                    size: 19,
                    color: focused ? primary : context.nexveero.textSecondary),
                const SizedBox(width: 9),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => context.read<SearchCubit>().onQueryChanged(v),
                    // The container is the field's surface, so strip the theme's
                    // fill + focus border (otherwise a box-in-a-box).
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Search people',
                    ),
                  ),
                ),
                BlocSelector<SearchCubit, SearchState, bool>(
                  selector: (s) => s.query.isNotEmpty,
                  builder: (context, hasText) => hasText
                      ? GestureDetector(
                          onTap: () {
                            _controller.clear();
                            context.read<SearchCubit>().clearQuery();
                          },
                          child: Icon(Icons.close,
                              size: 18, color: context.nexveero.textSecondary),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
      body: BlocBuilder<SearchCubit, SearchState>(
        builder: (context, state) {
          switch (state.status) {
            case SearchStatus.idle:
              return _RecentList(recents: state.recents, controller: _controller);
            case SearchStatus.searching:
              return const LoadingView();
            case SearchStatus.error:
              return ErrorView(
                message: state.errorMessage ?? 'Search failed',
                onRetry: () => context.read<SearchCubit>().runRecent(state.query),
              );
            case SearchStatus.empty:
              return EmptyView(
                title: 'No results',
                subtitle: 'No people match “${state.query.trim()}”.',
                icon: Icons.person_search_outlined,
              );
            case SearchStatus.results:
              return _Results(users: state.results);
          }
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {this.action});
  final String label;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.nexveero.textSecondary, letterSpacing: 1)),
          ?action,
        ],
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.recents, required this.controller});
  final List<String> recents;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    if (recents.isEmpty) {
      return const EmptyView(
        title: 'Search Nexveero',
        subtitle: 'Find people by name or number.',
        icon: Icons.search,
      );
    }
    return ListView(
      children: [
        _SectionHeader(
          'Recent',
          action: TextButton(
            onPressed: () => context.read<SearchCubit>().clearRecents(),
            child: const Text('Clear all'),
          ),
        ),
        for (final r in recents)
          ListTile(
            leading: Icon(Icons.history, color: context.nexveero.textSecondary),
            title: Text(r),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => context.read<SearchCubit>().removeRecent(r),
            ),
            onTap: () {
              controller.text = r;
              context.read<SearchCubit>().runRecent(r);
            },
          ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.users});
  final List<User> users;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: users.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return const _SectionHeader('Results');
        return _UserRow(user: users[i - 1]);
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final subtitle = (user.bio ?? '').isNotEmpty
        ? user.bio!
        : (user.isCreator ? 'Creator' : 'Member');
    return ListTile(
      leading: AppAvatar(
        name: user.name,
        imageUrl: MediaUrl.resolve(user.avatarUrl),
        size: 44,
      ),
      title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: user.isCreator
          ? Icon(Icons.verified, size: 18, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => _showPeek(context, user),
    );
  }

  void _showPeek(BuildContext context, User user) {
    AppOverlays.sheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAvatar(
            name: user.name,
            imageUrl: MediaUrl.resolve(user.avatarUrl),
            size: 72,
            ring: user.isCreator,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(user.name, style: Theme.of(ctx).textTheme.titleLarge),
          if ((user.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(user.bio!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'View profile',
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(AppRoutes.userProfile, extra: user.id);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Message',
            variant: AppButtonVariant.outline,
            onPressed: () {
              Navigator.of(ctx).pop();
              _startChat(context, user);
            },
          ),
        ],
      ),
    );
  }

  /// Starts (or reopens) a 1:1 chat. If the peer has Set-PIN on, prompts for
  /// their 4-digit PIN first, then opens the thread.
  Future<void> _startChat(BuildContext context, User user) async {
    final repo = sl<ChatRepository>();
    final pinReq = await AppLoader.run(repo.chatPinRequired(user.id));
    if (!context.mounted) return;

    String? pin;
    if (pinReq.valueOrNull == true) {
      // Full-screen "Enter PIN to chat" (design HTML 2933).
      pin = await context.push<String>(
        AppRoutes.enterPin,
        extra: {'name': user.name, 'avatar': user.avatarUrl},
      );
      if (pin == null) return; // cancelled
    }

    final result = await AppLoader.run(repo.startChat(user.id, pin: pin));
    if (!context.mounted) return;
    switch (result) {
      case Success(value: final conversation):
        context.push(AppRoutes.chatThread, extra: conversation);
      case Err(failure: final f):
        AppOverlays.snack(context, f.message);
    }
  }
}
