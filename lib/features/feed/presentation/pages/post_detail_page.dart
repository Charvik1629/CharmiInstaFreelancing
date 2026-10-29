import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/models/load.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../chat/domain/entities/conversation.dart';
import '../../../offers/presentation/widgets/make_offer_sheet.dart';
import '../../domain/repositories/feed_repository.dart';
import '../widgets/ask_question_sheet.dart';
import '../widgets/report_sheet.dart';

/// Post detail (design "Post Detail", HTML 1565): Instagram-style — author row
/// with a verified tick, an image carousel with page dots, the
/// Ask · Share · Offer · Report icon-action row, a bold-username caption and an
/// uppercase timestamp. Receives the [Load] via router `extra`.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.load});

  final Load load;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  /// Local mutable copy so the action row can flip to "View offer" in place
  /// after the viewer makes (or is found to already have) an offer.
  late Load load = widget.load;

  /// What to hand back to the opener (the feed) when this page is popped: the
  /// edited [Load] after an edit, the string 'deleted' after a delete, or null
  /// when nothing changed. Lets the feed update that row without a full refresh.
  Object? _popResult;

  Future<void> _request(BuildContext context) async {
    final result = await sl<FeedRepository>().requestLoad(load.id);
    if (!context.mounted) return;
    AppOverlays.snack(context,
        result.isSuccess ? 'Request sent — chat opened' : 'Could not send request');
  }

  Future<void> _offer(BuildContext context) async {
    final result =
        await MakeOfferSheet.show(context, loadId: load.id, loadTitle: load.title);
    if (result == null || !context.mounted) return;
    // Flip the action row to "View offer" and remember the opened thread.
    setState(() => load = load.copyWith(
          viewerHasOffer: true,
          offerConversationId: result.conversationId,
        ));
    if (result.alreadyExisted) {
      // Re-offer blocked by the server (409) — go straight into the chat.
      _openOfferChat(context);
    } else {
      AppOverlays.snack(context, 'Offer sent');
    }
  }

  /// Opens the viewer's existing offer chat for this post.
  void _viewOffer(BuildContext context) => _openOfferChat(context);

  void _openOfferChat(BuildContext context) {
    final id = load.offerConversationId;
    if (id == null) return;
    context.push(
      AppRoutes.chatThread,
      extra: Conversation(
        id: id,
        type: ConversationType.direct,
        title: load.author?.name ?? 'Offer',
        avatarUrl: load.author?.avatarUrl,
        peerId: load.author?.id,
        loadId: load.id,
      ),
    );
  }

  Future<void> _ask(BuildContext context) async {
    final body = await AskQuestionSheet.show(context, subtitle: load.title);
    if (body == null || body.isEmpty || !context.mounted) return;
    final result = await sl<FeedRepository>().askQuestion(load.id, body);
    if (!context.mounted) return;
    AppOverlays.snack(context,
        result.isSuccess ? 'Question sent' : 'Could not send question');
  }

  Future<void> _report(BuildContext context) async {
    final reason = await ReportSheet.show(context, subtitle: load.title);
    if (reason == null || !context.mounted) return;
    final result = await sl<FeedRepository>().reportLoad(load.id, reason);
    if (!context.mounted) return;
    AppOverlays.snack(
        context, result.isSuccess ? 'Report submitted' : 'Could not report');
  }

  /// Opens the post author's profile.
  void _viewAuthor(BuildContext context) {
    final id = load.author?.id;
    if (id != null) context.push(AppRoutes.userProfile, extra: id);
  }

  Future<void> _share(BuildContext context) async {
    final by = load.author?.name;
    // Share the post's canonical link (API share_url).
    final text = [
      load.title,
      if (by != null) 'by $by',
      if ((load.shareUrl ?? '').isNotEmpty) load.shareUrl,
    ].whereType<String>().join(' ');
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await AppOverlays.confirm(
      context,
      title: 'Delete post?',
      message: 'This removes the post for everyone. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final result = await AppLoader.run(sl<FeedRepository>().deleteLoad(load.id));
    if (!context.mounted) return;
    if (result.isSuccess) {
      AppOverlays.snack(context, 'Post deleted');
      _popResult = 'deleted';
      context.pop(_popResult);
    } else {
      AppOverlays.snack(context, result.failureOrNull?.message ?? 'Delete failed');
    }
  }

  Future<void> _boost(BuildContext context) async {
    final result = await AppLoader.run(sl<FeedRepository>().boostLoad(load.id));
    if (!context.mounted) return;
    AppOverlays.snack(context,
        result.isSuccess ? 'Post boosted 🚀' : (result.failureOrNull?.message ?? 'Could not boost'));
  }

  Future<void> _markSold(BuildContext context) async {
    final ok = await AppOverlays.confirm(
      context,
      title: 'Mark as sold?',
      message: 'This closes the post to new requests and offers.',
      confirmLabel: 'Mark sold',
    );
    if (!ok || !context.mounted) return;
    final result = await AppLoader.run(sl<FeedRepository>().markSold(load.id));
    if (!context.mounted) return;
    AppOverlays.snack(context,
        result.isSuccess ? 'Marked as sold' : (result.failureOrNull?.message ?? 'Could not update'));
  }

  /// The ⋯ menu (design "Post Menu"): owner sees Edit / Boost / Mark sold /
  /// Delete; others see Share / Report.
  Future<void> _openMenu(BuildContext context) async {
    final nex = context.nexveero;
    final action = await AppOverlays.sheet<String>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: AppSpacing.xs),
            child: Text('POST OPTIONS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: nex.textSecondary)),
          ),
          if (load.isOwn) ...[
            if (load.canEdit)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit post'),
                onTap: () => Navigator.of(ctx).pop('edit'),
              ),
            if (load.canBoost)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.rocket_launch),
                title: const Text('Boost post'),
                onTap: () => Navigator.of(ctx).pop('boost'),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Mark as sold'),
              onTap: () => Navigator.of(ctx).pop('sold'),
            ),
            if (load.canDelete)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(ctx).colorScheme.error),
                title: Text('Delete',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.ios_share),
              title: const Text('Share'),
              onTap: () => Navigator.of(ctx).pop('share'),
            ),
            if (load.canReport)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report'),
                onTap: () => Navigator.of(ctx).pop('report'),
              ),
            // Admins/moderators can delete others' posts (backend can_delete).
            if (load.canDelete)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(ctx).colorScheme.error),
                title: Text('Delete',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
          ],
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'edit':
        final updated = await context.push<Load>(AppRoutes.createPost, extra: load);
        if (updated != null && mounted) {
          setState(() {
            load = updated;
            _popResult = updated;
          });
        }
      case 'boost':
        _boost(context);
      case 'sold':
        _markSold(context);
      case 'delete':
        _delete(context);
      case 'report':
        _report(context);
      case 'share':
        _share(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Intercept every back (app-bar, gesture, system) so we can hand the edit
      // / delete result back to the feed, which updates that row in place.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !context.mounted) return;
        context.pop(_popResult);
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    final images = [
      for (final m in load.imageMedia) ?MediaUrl.resolve(m.url),
    ];
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Post')),
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        children: [
          // Author row with gradient avatar ring + verified tick.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: nex.primaryGradient,
                  ),
                  child: GestureDetector(
                    onTap: () => _viewAuthor(context),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: AppAvatar(
                        name: load.author?.name ?? '?',
                        imageUrl: MediaUrl.resolve(load.author?.avatarUrl),
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _viewAuthor(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(load.author?.name ?? 'Unknown',
                                  style: texts.titleMedium,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (load.isBusiness) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.verified,
                                  size: 15,
                                  color: Theme.of(context).colorScheme.primary),
                            ],
                          ],
                        ),
                        if (load.postType != null)
                          Text(load.postType!.name,
                              style: texts.bodySmall
                                  ?.copyWith(color: nex.textSecondary)),
                      ],
                    ),
                  ),
                ),
                InkResponse(
                  onTap: () => _openMenu(context),
                  radius: 22,
                  child: Icon(Icons.more_horiz, color: nex.iconInactive),
                ),
              ],
            ),
          ),
          // Image carousel — all media[] images with page dots.
          if (images.isNotEmpty)
            _ImageCarousel(urls: images)
          else
            const AspectRatio(
              aspectRatio: 1,
              child: ImagePlaceholder(role: PlaceholderRole.post, radius: 0),
            ),
          // Action row — Ask · Share · Offer · Report (owner: status line).
          if (load.isOwn)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Your post · ${load.status}',
                  style: TextStyle(color: nex.textSecondary)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  if (load.canAskQuestion)
                    Expanded(
                      child: _ActionIcon(
                          icon: Icons.help_outline,
                          label: 'Ask',
                          highlight: true,
                          onTap: () => _ask(context)),
                    ),
                  Expanded(
                    child: _ActionIcon(
                        icon: Icons.ios_share,
                        label: 'Share',
                        onTap: () => _share(context)),
                  ),
                  if (load.hasMyOffer)
                    Expanded(
                      child: _ActionIcon(
                          icon: Icons.local_offer,
                          label: 'View offer',
                          onTap: () => _viewOffer(context)),
                    )
                  else if (load.canMakeOffer)
                    Expanded(
                      child: _ActionIcon(
                          icon: Icons.sell_outlined,
                          label: 'Offer',
                          onTap: () => _offer(context)),
                    ),
                  if (load.canReport)
                    Expanded(
                      child: _ActionIcon(
                          icon: Icons.flag_outlined,
                          label: 'Report',
                          onTap: () => _report(context)),
                    ),
                ],
              ),
            ),
          // Caption — **username** caption text.
          if (load.title.isNotEmpty || (load.body ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xs),
              child: RichText(
                text: TextSpan(
                  style: texts.bodyMedium,
                  children: [
                    TextSpan(
                        text: '${load.author?.name ?? 'user'}  ',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: [load.title, load.body ?? '']
                            .where((s) => s.isNotEmpty)
                            .join('  ')),
                  ],
                ),
              ),
            ),
          if (load.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xs),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in load.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: nex.elevated,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text('#${t.name}',
                          style: texts.labelSmall
                              ?.copyWith(color: nex.textSecondary)),
                    ),
                ],
              ),
            ),
          if (load.createdAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xl),
              child: Text(load.createdAt!.timeAgo.toUpperCase(),
                  style: texts.labelSmall?.copyWith(
                      color: nex.textSecondary, letterSpacing: 0.6)),
            ),
          // Primary CTA for non-owners who can request.
          if (!load.isOwn && load.canMessage && !load.viewerHasRequested)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
              child: AppButton(
                  label: 'Request this post',
                  icon: Icons.bolt,
                  onPressed: () => _request(context)),
            )
          else if (!load.isOwn && load.viewerHasRequested)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
              child: AppButton(
                  label: 'Requested',
                  icon: Icons.check,
                  variant: AppButtonVariant.tonal,
                  onPressed: null),
            ),
        ],
      ),
    );
  }
}

/// Square media area with page dots (design "image 1 / 3"). One image today,
/// but structured for multi-image carousels once the API returns them.
class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel({required this.urls});
  final List<String> urls;

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Image.network(
              widget.urls[i],
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, _, _) =>
                  const ImagePlaceholder(role: PlaceholderRole.post, radius: 0),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const ImagePlaceholder(
                      role: PlaceholderRole.post, radius: 0),
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.urls.length; i++)
                    Container(
                      width: i == _page ? 16 : 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: i == _page ? 1 : 0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One column in the action row: icon on top, small bold label below.
class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final color = highlight
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface;
    return InkResponse(
      onTap: onTap,
      radius: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: nex.textSecondary)),
          ],
        ),
      ),
    );
  }
}
