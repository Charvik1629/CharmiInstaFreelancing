import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/business_post.dart';

/// Business feed post card (design "Business Feed", HTML 991–1128). Author row
/// with a verified tick, media, caption, and a **Share / Report** action row —
/// no Buy/Sell, Offer or Ask (those belong to the marketplace feed).
class BusinessPostCard extends StatelessWidget {
  const BusinessPostCard({
    super.key,
    required this.post,
    required this.onShare,
    required this.onReport,
  });

  final BusinessPost post;
  final VoidCallback onShare;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    final meta = [
      if (post.createdAt != null) post.createdAt!.timeAgo,
      if ((post.location ?? '').isNotEmpty) post.location,
    ].whereType<String>().join(' · ');
    final image = MediaUrl.resolve(post.imageUrl);

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
                AppAvatar(name: post.authorName, imageUrl: image == null ? null : MediaUrl.resolve(post.avatarUrl), size: 36),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(post.authorName,
                                style: texts.titleMedium,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (post.verified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified,
                                size: 15,
                                color: Theme.of(context).colorScheme.primary),
                          ],
                        ],
                      ),
                      if (meta.isNotEmpty)
                        Text(meta,
                            style: texts.bodySmall
                                ?.copyWith(color: nex.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.more_horiz, color: nex.iconInactive),
              ],
            ),
          ),
          if (image != null)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    const ImagePlaceholder(role: PlaceholderRole.post, radius: 0),
                errorWidget: (_, _, _) =>
                    const ImagePlaceholder(role: PlaceholderRole.post, radius: 0),
              ),
            ),
          if ((post.caption ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
              child: Text(post.caption!, style: texts.bodyMedium),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                    child: _ActionButton(
                        icon: Icons.ios_share, label: 'Share', onTap: onShare)),
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
