import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/models/load.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Feed post card (design section 04). Shows the author header, media, caption,
/// a boosted/type accent, and capability-driven actions: the primary
/// "Request this post" CTA for other users, plus an overflow menu (Report for
/// others; Edit/Boost/Delete for the owner).
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.load,
    required this.onRequest,
    required this.onReport,
    required this.onDelete,
    this.onEditDeferred,
    this.onBoost,
    this.onMarkSold,
    this.onOffer,
    this.onTap,
  });

  final Load load;
  final VoidCallback onRequest;
  final VoidCallback onReport;
  final VoidCallback onDelete;
  final VoidCallback? onEditDeferred;

  /// Boosts the post (owner). Wired to the real boost API.
  final VoidCallback? onBoost;

  /// Marks the post sold (owner). Wired to POST /loads/{id}/sold.
  final VoidCallback? onMarkSold;

  /// Shown as a "Make offer" action when the load allows it (can_make_offer).
  final VoidCallback? onOffer;

  /// Opens the post detail when the card body is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final nexveero = context.nexveero;
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: nexveero.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(load: load, onReport: onReport, onDelete: onDelete, onEditDeferred: onEditDeferred, onBoost: onBoost, onMarkSold: onMarkSold),
          if (load.hasImage) _Media(url: load.mediaUrl!) else if (load.hasFile) _FileChip(load: load),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (load.title.isNotEmpty)
                  Text(load.title, style: Theme.of(context).textTheme.titleMedium),
                if ((load.body ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(load.body!, style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: AppSpacing.md),
                _Actions(load: load, onRequest: onRequest, onOffer: onOffer),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.load,
    required this.onReport,
    required this.onDelete,
    this.onEditDeferred,
    this.onBoost,
    this.onMarkSold,
  });
  final Load load;
  final VoidCallback onReport;
  final VoidCallback onDelete;
  final VoidCallback? onEditDeferred;

  /// Boosts the post (owner). Wired to the real boost API.
  final VoidCallback? onBoost;
  final VoidCallback? onMarkSold;

  @override
  Widget build(BuildContext context) {
    final nexveero = context.nexveero;
    final author = load.author;
    final meta = [
      if (load.createdAt != null) load.createdAt!.timeAgo,
      if (load.postType != null) load.postType!.name,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.sm),
      child: Row(
        children: [
          AppAvatar(name: author?.name ?? '?', imageUrl: author?.avatarUrl, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(author?.name ?? 'Unknown',
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (load.isBusiness) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.verified, size: 16, color: Theme.of(context).colorScheme.primary),
                    ],
                  ],
                ),
                if (meta.isNotEmpty)
                  Text(meta, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: nexveero.textSecondary)),
              ],
            ),
          ),
          if (load.isBoosted) _BoostedBadge(),
          _OverflowMenu(load: load, onReport: onReport, onDelete: onDelete, onEditDeferred: onEditDeferred, onBoost: onBoost, onMarkSold: onMarkSold),
        ],
      ),
    );
  }
}

class _BoostedBadge extends StatelessWidget {
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
        Text('Boosted', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.load,
    required this.onReport,
    required this.onDelete,
    this.onEditDeferred,
    this.onBoost,
    this.onMarkSold,
  });
  final Load load;
  final VoidCallback onReport;
  final VoidCallback onDelete;
  final VoidCallback? onEditDeferred;

  /// Boosts the post (owner). Wired to the real boost API.
  final VoidCallback? onBoost;
  final VoidCallback? onMarkSold;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_horiz),
      onPressed: () => _open(context),
    );
  }

  /// Design "Post Menu" — a bottom sheet (matching the Business ⋯ menu), not a
  /// dropdown. Owner sees Edit / Boost / Mark sold / Delete; others see Report.
  Future<void> _open(BuildContext context) async {
    final nex = context.nexveero;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: nex.border,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                child: Text('POST OPTIONS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: nex.textSecondary)),
              ),
              if (load.isOwn) ...[
                if (load.canEdit)
                  _SheetRow(
                      icon: Icons.edit_outlined,
                      tint: nex.gradientStart,
                      title: 'Edit post',
                      subtitle: 'Update photos, caption, or details',
                      onTap: () => Navigator.of(ctx).pop('edit')),
                if (load.canBoost)
                  _SheetRow(
                      icon: Icons.rocket_launch,
                      tint: nex.gradientEnd,
                      title: 'Boost post',
                      subtitle: 'Feature it to more people',
                      onTap: () => Navigator.of(ctx).pop('boost')),
                if (onMarkSold != null)
                  _SheetRow(
                      icon: Icons.check_circle_outline,
                      tint: nex.success,
                      title: 'Mark as sold',
                      subtitle: 'Close it to new requests',
                      onTap: () => Navigator.of(ctx).pop('sold')),
                if (load.canDelete)
                  _SheetRow(
                      icon: Icons.delete_outline,
                      tint: Theme.of(ctx).colorScheme.error,
                      title: 'Delete',
                      subtitle: 'Remove this post',
                      danger: true,
                      onTap: () => Navigator.of(ctx).pop('delete')),
              ] else if (load.canReport)
                _SheetRow(
                    icon: Icons.flag_outlined,
                    tint: Theme.of(ctx).colorScheme.error,
                    title: 'Report',
                    subtitle: 'Flag this post for review',
                    onTap: () => Navigator.of(ctx).pop('report')),
            ],
          ),
        ),
      ),
    );
    switch (action) {
      case 'report':
        onReport();
      case 'delete':
        onDelete();
      case 'edit':
        onEditDeferred?.call();
      case 'boost':
        onBoost?.call();
      case 'sold':
        onMarkSold?.call();
    }
  }
}

/// A design-styled option row (icon tile + title + subtitle) for the post menu.
class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 22, color: tint),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: danger
                              ? Theme.of(context).colorScheme.error
                              : null)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: nex.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: nex.iconInactive),
          ],
        ),
      ),
    );
  }
}

class _Media extends StatelessWidget {
  const _Media({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    // media_url is server-relative; resolve against the configured base host.
    final full = url.startsWith('http') ? url : '${AppConfig.current.baseUrl}$url';
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: CachedNetworkImage(
        imageUrl: full,
        fit: BoxFit.cover,
        placeholder: (_, _) => const ImagePlaceholder(role: PlaceholderRole.post, radius: 0),
        errorWidget: (_, _, _) =>
            const ImagePlaceholder(role: PlaceholderRole.post, radius: 0),
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.load});
  final Load load;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.nexveero.elevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(children: [
        Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(load.mediaMime ?? 'Attachment',
            style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.load, required this.onRequest, this.onOffer});
  final Load load;
  final VoidCallback onRequest;
  final VoidCallback? onOffer;

  @override
  Widget build(BuildContext context) {
    if (load.isOwn) {
      // Owner sees a status pill instead of a request CTA.
      return Align(
        alignment: Alignment.centerLeft,
        child: Text('Your post · ${load.status}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.nexveero.textSecondary)),
      );
    }
    if (load.viewerHasRequested) {
      return const AppButton(
        label: 'Requested',
        icon: Icons.check,
        variant: AppButtonVariant.tonal,
        onPressed: null,
      );
    }

    final canOffer = load.canMakeOffer && onOffer != null;
    if (load.canMessage) {
      return Row(
        children: [
          Expanded(
            child: AppButton(label: 'Request this post', icon: Icons.bolt, onPressed: onRequest),
          ),
          if (canOffer) ...[
            const SizedBox(width: AppSpacing.md),
            AppButton(
              label: 'Offer',
              icon: Icons.local_offer_outlined,
              variant: AppButtonVariant.outline,
              expanded: false,
              onPressed: onOffer,
            ),
          ],
        ],
      );
    }
    if (canOffer) {
      return AppButton(
        label: 'Make an offer',
        icon: Icons.local_offer_outlined,
        variant: AppButtonVariant.tonal,
        onPressed: onOffer,
      );
    }
    return const SizedBox.shrink();
  }
}
