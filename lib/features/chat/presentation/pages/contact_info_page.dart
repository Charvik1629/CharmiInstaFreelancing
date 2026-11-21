import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/widgets/message_link_text.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../cubit/conversation_cubit.dart';
import '../../domain/entities/shared_content.dart';
import 'attachment_view_page.dart';
import 'disappearing_messages_page.dart';

/// Contact Info (design "Contact Info", HTML 2276): profile header + Media /
/// Links / Docs tabs, all derived from the conversation's messages. Applies to
/// direct and group threads (both user and admin see the same view).
class ContactInfoPage extends StatelessWidget {
  const ContactInfoPage({super.key, required this.conversation});

  final Conversation conversation;

  Future<void> _block(BuildContext context) async {
    final ok = await AppOverlays.confirm(
      context,
      title: 'Block ${conversation.title}?',
      message: 'They won\'t be able to message you.',
      confirmLabel: 'Block',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final result = await context.read<ConversationCubit>().blockPeer();
    if (!context.mounted) return;
    AppOverlays.snack(
      context,
      result.isSuccess
          ? 'User blocked'
          : (result.failureOrNull?.message ?? 'Could not block'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meId = sl<AuthCubit>().state.user?.id;
    return BlocProvider(
      create: (_) =>
          ConversationCubit(sl<ChatRepository>(), conversation, meId: meId)
            ..loadDetails(),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Contact info'),
            actions: [
              if (conversation.peerId != null && !conversation.isSelf)
                Builder(
                  builder: (ctx) => PopupMenuButton<String>(
                    onSelected: (_) => _block(ctx),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'block', child: Text('Block user')),
                    ],
                  ),
                ),
            ],
          ),
          body: _SharedContentView(conversation: conversation),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.conversation});
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          AppAvatar(
            name: conversation.title,
            imageUrl: MediaUrl.resolve(conversation.avatarUrl),
            size: 96,
            enlargeOnTap: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            conversation.title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if ((conversation.subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              conversation.subtitle!,
              style: TextStyle(color: nex.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          // Direct threads carry a peer id — offer a jump to their profile.
          if (conversation.peerId != null && !conversation.isSelf) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'View business',
              icon: Icons.storefront_outlined,
              variant: AppButtonVariant.outline,
              expanded: false,
              onPressed: () => context.push(
                AppRoutes.userProfile,
                extra: conversation.peerId!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.items});
  final List<ChatMessage> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyTab(
        icon: Icons.photo_library_outlined,
        label: 'No media yet',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        final url = MediaUrl.resolve(m.imageUrl ?? m.attachmentUrl);
        final isVideo = m.attachmentKind == 'video';
        return GestureDetector(
          onTap: url == null
              ? null
              : () {
                  if (isVideo) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AttachmentViewPage(
                          url: url,
                          name: m.attachmentName ?? 'Video',
                          video: true,
                        ),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FullImageView(url: url),
                      ),
                    );
                  }
                },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url != null)
                CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ImagePlaceholder(
                    role: PlaceholderRole.post,
                    radius: 0,
                  ),
                  errorWidget: (_, _, _) => const ImagePlaceholder(
                    role: PlaceholderRole.post,
                    radius: 0,
                  ),
                )
              else
                const ImagePlaceholder(role: PlaceholderRole.post, radius: 0),
              if (isVideo)
                Container(
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LinksList extends StatelessWidget {
  const _LinksList({required this.items, required this.regex});
  final List<ChatMessage> items;
  final RegExp regex;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyTab(icon: Icons.link, label: 'No links shared yet');
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: context.nexveero.border),
      itemBuilder: (_, i) {
        final m = items[i];
        final url = regex.firstMatch(m.body ?? '')?.group(0) ?? '';
        final host = Uri.tryParse(url)?.host ?? url;
        return ListTile(
          onTap: url.isEmpty
              ? null
              : () => launchUrl(
                  Uri.parse(MessageLinks.normalize(url)),
                  mode: LaunchMode.externalApplication,
                ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.nexveero.elevated,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.link,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            host.isNotEmpty ? host : url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          trailing: m.createdAt == null
              ? null
              : Text(
                  m.createdAt!.timeAgo,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
        );
      },
    );
  }
}

class _DocsList extends StatelessWidget {
  const _DocsList({required this.items});
  final List<ChatMessage> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyTab(
        icon: Icons.description_outlined,
        label: 'No documents yet',
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: context.nexveero.border),
      itemBuilder: (_, i) {
        final m = items[i];
        final audio = m.attachmentKind == 'audio';
        final docUrl = MediaUrl.resolve(m.attachmentUrl);
        return ListTile(
          onTap: docUrl == null
              ? null
              : () {
                  if (Uri.parse(docUrl).path.toLowerCase().endsWith('.pdf') ||
                      (m.attachmentName ?? '').toLowerCase().endsWith('.pdf')) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AttachmentViewPage(
                          url: docUrl,
                          name: m.attachmentName ?? 'PDF',
                          video: false,
                        ),
                      ),
                    );
                  } else {
                    launchUrl(
                      Uri.parse(docUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.nexveero.elevated,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              audio ? Icons.audiotrack : Icons.insert_drive_file_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            m.attachmentName ?? (audio ? 'Audio' : 'Document'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: m.createdAt == null
              ? null
              : Text(
                  m.createdAt!.timeAgo,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
        );
      },
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: nex.iconInactive),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: TextStyle(color: nex.textSecondary)),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar, {this.signature = ''});
  final TabBar tabBar;

  /// Changes whenever the tab counts change, so the pinned header rebuilds.
  final String signature;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      oldDelegate.signature != signature;
}

/// Each tab pages independently; totals are authoritative server values.
class _SharedContentView extends StatefulWidget {
  const _SharedContentView({required this.conversation});
  final Conversation conversation;
  @override
  State<_SharedContentView> createState() => _SharedContentViewState();
}

class _SharedContentViewState extends State<_SharedContentView> {
  SharedContent? _totals;
  void _update(SharedContent content) {
    if (mounted) setState(() => _totals = content);
  }

  @override
  Widget build(BuildContext context) => NestedScrollView(
    headerSliverBuilder: (_, _) => [
      SliverToBoxAdapter(child: _Header(conversation: widget.conversation)),
      SliverToBoxAdapter(
        child: BlocBuilder<ConversationCubit, ConversationState>(
          builder: (ctx, state) => ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Disappearing messages'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.disappearing.displayLabel),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: !ctx.read<ConversationCubit>().canSend
                ? null
                : () async {
                    final cubit = ctx.read<ConversationCubit>();
                    await Navigator.of(ctx).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => DisappearingMessagesPage(
                          repository: sl<ChatRepository>(),
                          initial: cubit.state.disappearing,
                          onApply: cubit.setDisappearing,
                        ),
                      ),
                    );
                  },
          ),
        ),
      ),
      SliverPersistentHeader(
        pinned: true,
        delegate: _TabBarDelegate(
          TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(text: 'Media (${_totals?.mediaCount ?? '…'})'),
              Tab(text: 'Links (${_totals?.linksCount ?? '…'})'),
              Tab(text: 'Docs (${_totals?.documentsCount ?? '…'})'),
            ],
          ),
          signature:
              '${_totals?.mediaCount}-${_totals?.linksCount}-${_totals?.documentsCount}',
        ),
      ),
    ],
    body: TabBarView(
      children: [
        for (final type in ['media', 'links', 'documents'])
          _SharedPageTab(
            key: ValueKey(type),
            conversationId: widget.conversation.id,
            type: type,
            onTotals: _update,
          ),
      ],
    ),
  );
}

class _SharedPageTab extends StatefulWidget {
  const _SharedPageTab({
    super.key,
    required this.conversationId,
    required this.type,
    required this.onTotals,
  });
  final int conversationId;
  final String type;
  final ValueChanged<SharedContent> onTotals;
  @override
  State<_SharedPageTab> createState() => _SharedPageTabState();
}

class _SharedPageTabState extends State<_SharedPageTab>
    with AutomaticKeepAliveClientMixin {
  final List<ChatMessage> _items = [];
  bool _loading = false, _hasMore = true;
  int _page = 1;
  String? _error;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sl<ChatRepository>().getShared(
      widget.conversationId,
      type: widget.type,
      page: _page,
    );
    if (!mounted) return;
    final content = result.valueOrNull;
    if (content != null) {
      widget.onTotals(content);
      setState(() {
        final known = _items.map((message) => message.id).toSet();
        _items.addAll(content.items.where((message) => known.add(message.id)));
        _page = content.meta.currentPage + 1;
        _hasMore = content.meta.hasMore && content.items.isNotEmpty;
        _loading = false;
      });
    } else {
      setState(() {
        _error = result.failureOrNull?.message ?? 'Could not load shared items';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_items.isEmpty && _loading) return const LoadingView();
    if (_items.isEmpty && _error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    return Column(
      children: [
        Expanded(
          child: switch (widget.type) {
            'media' => _MediaGrid(items: _items),
            'links' => _LinksList(items: _items, regex: MessageLinks.pattern),
            _ => _DocsList(items: _items),
          },
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        if (!_loading && _hasMore)
          TextButton(
            onPressed: _load,
            child: Text(_error == null ? 'Load more' : 'Retry'),
          ),
      ],
    );
  }
}
