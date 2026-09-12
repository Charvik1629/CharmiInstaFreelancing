import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../cubit/conversation_cubit.dart';

/// Contact Info (design "Contact Info", HTML 2276): profile header + Media /
/// Links / Docs tabs, all derived from the conversation's messages. Applies to
/// direct and group threads (both user and admin see the same view).
class ContactInfoPage extends StatelessWidget {
  const ContactInfoPage({super.key, required this.conversation});

  final Conversation conversation;

  static final _urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);

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
    AppOverlays.snack(context,
        result.isSuccess ? 'User blocked' : (result.failureOrNull?.message ?? 'Could not block'));
  }

  @override
  Widget build(BuildContext context) {
    final meId = sl<AuthCubit>().state.user?.id;
    return BlocProvider(
      create: (_) =>
          ConversationCubit(sl<ChatRepository>(), conversation, meId: meId)..load(),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Contact info'),
            actions: [
              if (conversation.peerId != null)
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
          body: BlocBuilder<ConversationCubit, ConversationState>(
            builder: (context, state) {
              final msgs = state.messages;
              final media = msgs
                  .where((m) => m.hasImage || m.attachmentKind == 'video')
                  .toList();
              final docs = msgs
                  .where((m) =>
                      m.attachmentKind == 'file' || m.attachmentKind == 'audio')
                  .toList();
              final links = msgs
                  .where((m) => (m.body ?? '').contains(_urlRegex))
                  .toList();
              return NestedScrollView(
                headerSliverBuilder: (_, _) => [
                  SliverToBoxAdapter(child: _Header(conversation: conversation)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      TabBar(
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: context.nexveero.textSecondary,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        tabs: [
                          Tab(text: 'Media (${media.length})'),
                          Tab(text: 'Links (${links.length})'),
                          Tab(text: 'Docs (${docs.length})'),
                        ],
                      ),
                    ),
                  ),
                ],
                body: state.status == ThreadStatus.loading
                    ? const LoadingView()
                    : TabBarView(
                        children: [
                          _MediaGrid(items: media),
                          _LinksList(items: links, regex: _urlRegex),
                          _DocsList(items: docs),
                        ],
                      ),
              );
            },
          ),
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
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        children: [
          AppAvatar(
              name: conversation.title,
              imageUrl: MediaUrl.resolve(conversation.avatarUrl),
              size: 96),
          const SizedBox(height: AppSpacing.md),
          Text(conversation.title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          if ((conversation.subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(conversation.subtitle!,
                style: TextStyle(color: nex.textSecondary),
                textAlign: TextAlign.center),
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
      return const _EmptyTab(icon: Icons.photo_library_outlined, label: 'No media yet');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 3, crossAxisSpacing: 3),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final m = items[i];
        final url = MediaUrl.resolve(m.imageUrl ?? m.attachmentUrl);
        final isVideo = m.attachmentKind == 'video';
        return Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    const ImagePlaceholder(role: PlaceholderRole.post, radius: 0),
                errorWidget: (_, _, _) =>
                    const ImagePlaceholder(role: PlaceholderRole.post, radius: 0),
              )
            else
              const ImagePlaceholder(role: PlaceholderRole.post, radius: 0),
            if (isVideo)
              Container(
                color: Colors.black26,
                alignment: Alignment.center,
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
              ),
          ],
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
      separatorBuilder: (_, _) => Divider(height: 1, color: context.nexveero.border),
      itemBuilder: (_, i) {
        final m = items[i];
        final url = regex.firstMatch(m.body ?? '')?.group(0) ?? '';
        final host = Uri.tryParse(url)?.host ?? url;
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.nexveero.elevated,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.link, color: Theme.of(context).colorScheme.primary),
          ),
          title: Text(host.isNotEmpty ? host : url, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          trailing: m.createdAt == null
              ? null
              : Text(m.createdAt!.timeAgo,
                  style: Theme.of(context).textTheme.labelSmall),
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
      return const _EmptyTab(icon: Icons.description_outlined, label: 'No documents yet');
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: context.nexveero.border),
      itemBuilder: (_, i) {
        final m = items[i];
        final audio = m.attachmentKind == 'audio';
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.nexveero.elevated,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(audio ? Icons.audiotrack : Icons.insert_drive_file_outlined,
                color: Theme.of(context).colorScheme.primary),
          ),
          title: Text(m.attachmentName ?? (audio ? 'Audio' : 'Document'),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: m.createdAt == null
              ? null
              : Text(m.createdAt!.timeAgo,
                  style: Theme.of(context).textTheme.labelSmall),
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
  _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Theme.of(context).colorScheme.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
