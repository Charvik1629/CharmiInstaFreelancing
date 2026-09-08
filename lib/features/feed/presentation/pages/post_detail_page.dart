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
import '../widgets/report_sheet.dart';

/// Post detail (design "Post Detail"). Full view of a single load with the
/// viewer's available actions (Request / Offer / Ask / Report). Receives the
/// [Load] via router `extra` — no extra fetch needed.
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
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ask a question'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Your question'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Send')),
        ],
      ),
    );
    if (body == null || body.isEmpty || !context.mounted) return;
    final result = await sl<FeedRepository>().askQuestion(load.id, body);
    if (!context.mounted) return;
    AppOverlays.snack(context,
        result.isSuccess ? 'Question sent' : 'Could not send question');
  }

  Future<void> _report(BuildContext context) async {
    final reason = await ReportSheet.show(context);
    if (reason == null || !context.mounted) return;
    final result = await sl<FeedRepository>().reportLoad(load.id, reason);
    if (!context.mounted) return;
    AppOverlays.snack(
        context, result.isSuccess ? 'Report submitted' : 'Could not report');
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: ListView(
        children: [
          ListTile(
            leading: AppAvatar(
                name: load.author?.name ?? '',
                imageUrl: MediaUrl.resolve(load.author?.avatarUrl),
                size: 44),
            title: Text(load.author?.name ?? 'Unknown'),
            subtitle: Text([
              if (load.postType != null) load.postType!.name,
              if (load.createdAt != null) load.createdAt!.timeAgo,
            ].join(' · ')),
          ),
          if (load.hasImage)
            Image.network(
              MediaUrl.resolve(load.mediaUrl)!,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const AspectRatio(
                aspectRatio: 4 / 3,
                child: ImagePlaceholder(role: PlaceholderRole.post, radius: 0),
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const AspectRatio(
                      aspectRatio: 4 / 3,
                      child: ImagePlaceholder(
                          role: PlaceholderRole.post, radius: 0)),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (load.title.isNotEmpty) Text(load.title, style: texts.titleLarge),
                if ((load.body ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(load.body!, style: texts.bodyMedium),
                ],
                const SizedBox(height: AppSpacing.xl),
                if (load.isOwn)
                  Text('Your post · ${load.status}',
                      style: TextStyle(color: context.nexveero.textSecondary))
                else
                  _Actions(load: load, onRequest: _request, onOffer: _offer, onAsk: _ask, onReport: _report),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.load,
    required this.onRequest,
    required this.onOffer,
    required this.onAsk,
    required this.onReport,
  });

  final Load load;
  final Future<void> Function(BuildContext) onRequest;
  final Future<void> Function(BuildContext) onOffer;
  final Future<void> Function(BuildContext) onAsk;
  final Future<void> Function(BuildContext) onReport;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (load.canMessage && !load.viewerHasRequested)
          AppButton(label: 'Request this post', icon: Icons.bolt, onPressed: () => onRequest(context))
        else if (load.viewerHasRequested)
          const AppButton(label: 'Requested', icon: Icons.check, variant: AppButtonVariant.tonal, onPressed: null),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            if (load.canMakeOffer)
              Expanded(
                child: AppButton(
                  label: 'Offer',
                  icon: Icons.local_offer_outlined,
                  variant: AppButtonVariant.outline,
                  onPressed: () => onOffer(context),
                ),
              ),
            if (load.canMakeOffer && load.canAskQuestion)
              const SizedBox(width: AppSpacing.md),
            if (load.canAskQuestion)
              Expanded(
                child: AppButton(
                  label: 'Ask',
                  icon: Icons.help_outline,
                  variant: AppButtonVariant.outline,
                  onPressed: () => onAsk(context),
                ),
              ),
          ],
        ),
        if (load.canReport) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => onReport(context),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('Report this post'),
          ),
        ],
      ],
    );
  }
}
