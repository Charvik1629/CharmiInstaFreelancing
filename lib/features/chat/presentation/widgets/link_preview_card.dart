import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/link_preview/link_preview_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// A WhatsApp-style link preview below a message body (`POST /link-previews`).
/// Renders nothing until the metadata resolves (and nothing if there's none).
class LinkPreviewCard extends StatefulWidget {
  const LinkPreviewCard({super.key, required this.url, required this.mine});
  final String url;
  final bool mine;

  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  late final Future<LinkPreview?> _future =
      sl<LinkPreviewService>().fetch(widget.url);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LinkPreview?>(
      future: _future,
      builder: (context, snap) {
        final p = snap.data;
        if (p == null || !p.hasContent) return const SizedBox.shrink();
        final onTint = widget.mine ? Colors.white : null;
        final subtle = widget.mine
            ? Colors.white70
            : context.nexveero.textSecondary;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: InkWell(
            onTap: () => launchUrl(Uri.parse(widget.url),
                mode: LaunchMode.externalApplication),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              width: 240,
              decoration: BoxDecoration(
                color: (widget.mine ? Colors.white : context.nexveero.elevated)
                    .withValues(alpha: widget.mine ? 0.15 : 1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.imageUrl != null)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: p.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((p.siteName ?? '').isNotEmpty)
                          Text(p.siteName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: subtle)),
                        if ((p.title ?? '').isNotEmpty)
                          Text(p.title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: onTint)),
                        if ((p.description ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(p.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: subtle)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
