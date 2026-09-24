import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/models/load.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';

/// Business feed card (design "Business Feed", HTML 991–1128). Backed by a
/// [Load] of post_type=Business. Author row with a verified tick, media,
/// caption, and a **Share / Report** action row. The owner's overflow (⋯) opens
/// the Business options sheet (Edit / Boost) — wired by the page.
class BusinessPostCard extends StatelessWidget {
  const BusinessPostCard({
    super.key,
    required this.load,
    required this.onShare,
    required this.onReport,
    this.onAsk,
    this.onMore,
  });

  final Load load;
  final VoidCallback onShare;
  final VoidCallback onReport;

  /// Ask a question about the post (can_ask_question). Null hides the action.
  final VoidCallback? onAsk;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    final image = MediaUrl.resolve(load.mediaUrl);
    final caption = [load.title, load.body ?? '']
        .where((s) => s.isNotEmpty)
        .join('  ');

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: nex.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.sm),
            child: Row(
              children: [
                AppAvatar(
                    name: load.author?.name ?? '?',
                    imageUrl: MediaUrl.resolve(load.author?.avatarUrl),
                    size: 36),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(load.author?.name ?? 'Business',
                                style: texts.titleMedium,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.verified,
                              size: 15,
                              color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                      if (load.createdAt != null)
                        Text(load.createdAt!.timeAgo,
                            style: texts.bodySmall
                                ?.copyWith(color: nex.textSecondary)),
                    ],
                  ),
                ),
                if (load.isBoosted) const _BoostedTag(),
                // ⋯ is owner-only (Edit / Boost). Non-owners use the inline
                // Ask / Share / Report row below — so no direct-to-report jump.
                if (load.isOwn && onMore != null)
                  IconButton(
                    icon: const Icon(Icons.more_horiz),
                    color: nex.iconInactive,
                    onPressed: onMore,
                  ),
              ],
            ),
          ),
          if (image != null)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                placeholder: (_, _) => const ImagePlaceholder(
                    role: PlaceholderRole.post, radius: 0),
                errorWidget: (_, _, _) => const ImagePlaceholder(
                    role: PlaceholderRole.post, radius: 0),
              ),
            ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
              child: Text(caption, style: texts.bodyMedium),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            child: Row(
              children: [
                // Ask a question — hidden for own posts / when not permitted.
                if (!load.isOwn && load.canAskQuestion && onAsk != null)
                  Expanded(
                      child: _ActionButton(
                          icon: Icons.help_outline,
                          label: 'Ask',
                          onTap: onAsk!)),
                Expanded(
                    child: _ActionButton(
                        icon: Icons.ios_share, label: 'Share', onTap: onShare)),
                // Report — never on the owner's own post (API also blocks it).
                if (!load.isOwn && load.canReport)
                  Expanded(
                      child: _ActionButton(
                          icon: Icons.flag_outlined,
                          label: 'Report',
                          onTap: onReport)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoostedTag extends StatelessWidget {
  const _BoostedTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        gradient: context.nexveero.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.rocket_launch, size: 12, color: Colors.white),
        SizedBox(width: 3),
        Text('Boosted',
            style: TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return InkResponse(
      onTap: onTap,
      radius: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: nex.iconInactive),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: nex.textSecondary)),
          ],
        ),
      ),
    );
  }
}
