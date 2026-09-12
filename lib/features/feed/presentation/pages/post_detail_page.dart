import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/models/load.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../offers/presentation/widgets/make_offer_sheet.dart';
import '../../domain/repositories/feed_repository.dart';
import '../widgets/ask_question_sheet.dart';
import '../widgets/report_sheet.dart';

/// Post detail (design "Post Detail", HTML 1565): Instagram-style — author row
/// with a verified tick, an image carousel with page dots, the
/// Ask · Share · Offer · Report icon-action row, a bold-username caption and an
/// uppercase timestamp. Receives the [Load] via router `extra`.
class PostDetailPage extends StatelessWidget {
  const PostDetailPage({super.key, required this.load});

  final Load load;

  Future<void> _request(BuildContext context) async {
    final result = await sl<FeedRepository>().requestLoad(load.id);
    if (!context.mounted) return;
    AppOverlays.snack(context,
        result.isSuccess ? 'Request sent — chat opened' : 'Could not send request');
  }

  Future<void> _offer(BuildContext context) async {
    final offer =
        await MakeOfferSheet.show(context, loadId: load.id, loadTitle: load.title);
    if (offer != null && context.mounted) AppOverlays.snack(context, 'Offer sent');
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

  void _share(BuildContext context) {
    // The system share sheet arrives with share_plus; surface intent for now.
    AppOverlays.snack(context, 'Sharing opens the system share sheet.');
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    final image = MediaUrl.resolve(load.mediaUrl);
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Post')),
      body: ListView(
        padding: EdgeInsets.zero,
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
                const SizedBox(width: AppSpacing.md),
                Expanded(
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
                Icon(Icons.more_horiz, color: nex.iconInactive),
              ],
            ),
          ),
          // Image (carousel-ready; a single load has one image today).
          if (image != null)
            _ImageCarousel(urls: [image])
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
                  if (load.canMakeOffer)
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
