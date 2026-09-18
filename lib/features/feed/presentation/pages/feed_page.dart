import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/constants/ad_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/models/load.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../chat/domain/entities/conversation.dart';
import '../../../offers/presentation/widgets/make_offer_sheet.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../cubit/feed_cubit.dart';
import '../widgets/boost_confirm_dialog.dart';
import '../widgets/request_success_sheet.dart';
import '../widgets/feed_ad_slot.dart';
import '../widgets/post_card.dart';
import '../widgets/report_sheet.dart';

/// The home feed. Lists posts (loads) with filters, pull-to-refresh and
/// infinite scroll, and handles the per-post actions.
class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<FeedCubit>()..load(),
      child: const _FeedView(),
    );
  }
}

class _FeedView extends StatefulWidget {
  const _FeedView();

  @override
  State<_FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<_FeedView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      context.read<FeedCubit>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    final feed = context.read<FeedCubit>();
    final created = await context.push<Load>(AppRoutes.createPost);
    if (created == null || !mounted) return;
    feed.prepend(created);
    AppOverlays.snack(context, 'Post published');
  }

  Future<void> _offer(Load load) async {
    final offer = await MakeOfferSheet.show(context,
        loadId: load.id, loadTitle: load.title);
    if (offer == null || !mounted) return;
    AppOverlays.snack(context, 'Offer sent');
  }

  Future<void> _request(Load load) async {
    final conversationId = await context.read<FeedCubit>().request(load);
    if (!mounted) return;
    if (conversationId == null) {
      AppOverlays.snack(context, 'Could not send request');
      return;
    }
    // Design "Request Success": a sheet confirming the auto-created chat.
    final open = await RequestSuccessSheet.show(
      context,
      peerName: load.author?.name ?? 'the seller',
      peerAvatarUrl: load.author?.avatarUrl,
    );
    if (!open || !mounted) return;
    context.push(
      AppRoutes.chatThread,
      extra: Conversation(
        id: conversationId,
        type: ConversationType.direct,
        title: load.author?.name ?? 'Chat',
        avatarUrl: load.author?.avatarUrl,
      ),
    );
  }

  Future<void> _report(Load load) async {
    final reason = await ReportSheet.show(context, subtitle: load.title);
    if (reason == null || !mounted) return;
    final result = await context.read<FeedCubit>().report(load, reason);
    if (!mounted) return;
    AppOverlays.snack(
      context,
      result.isSuccess ? 'Report submitted' : (result.failureOrNull?.message ?? 'Failed'),
    );
  }

  Future<void> _delete(Load load) async {
    final confirmed = await AppOverlays.confirm(
      context,
      title: 'Delete post?',
      message: 'This removes the post for everyone. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final result = await context.read<FeedCubit>().delete(load);
    if (!mounted) return;
    AppOverlays.snack(context, result.isSuccess ? 'Post deleted' : 'Delete failed');
  }

  Future<void> _boost(Load load) async {
    // Pull the live cost + balance so the confirm card matches the design's
    // Duration / Cost / Your balance breakdown.
    final wallet = (await sl<WalletRepository>().getWallet()).valueOrNull;
    if (!mounted) return;
    final confirmed = await BoostConfirmDialog.show(
      context,
      cost: wallet?.boostCost ?? 20,
      balance: wallet?.creditBalance ?? 0,
    );
    if (!confirmed || !mounted) return;
    final result = await context.read<FeedCubit>().boost(load);
    if (!mounted) return;
    AppOverlays.snack(
      context,
      result.isSuccess
          ? 'Post boosted 🚀'
          : (result.failureOrNull?.message ?? 'Could not boost'),
    );
  }

  Future<void> _markSold(Load load) async {
    final ok = await AppOverlays.confirm(
      context,
      title: 'Mark as sold?',
      message: 'This closes the post to new requests and offers.',
      confirmLabel: 'Mark sold',
    );
    if (!ok || !mounted) return;
    final result = await context.read<FeedCubit>().markSold(load);
    if (!mounted) return;
    AppOverlays.snack(
      context,
      result.isSuccess
          ? 'Marked as sold'
          : (result.failureOrNull?.message ?? 'Could not update'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.add_box_outlined),
          tooltip: 'Create post',
          onPressed: _createPost,
        ),
        centerTitle: true,
        title: _GradientWordmark(),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
            onPressed: () => context.push(AppRoutes.notifications),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          const _FilterBar(),
          Expanded(
            child: BlocBuilder<FeedCubit, FeedState>(
              builder: (context, state) => _FeedBody(
                state: state,
                scrollController: _scrollController,
                onRequest: _request,
                onReport: _report,
                onDelete: _delete,
                onOffer: _offer,
                onBoost: _boost,
                onMarkSold: _markSold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<FeedCubit>();
    final selected = cubit.state.filter;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        children: [
          for (final f in FeedFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: AppChip(
                label: f.label,
                selected: f == selected,
                onTap: () => context.read<FeedCubit>().setFilter(f),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.state,
    required this.scrollController,
    required this.onRequest,
    required this.onReport,
    required this.onDelete,
    required this.onOffer,
    required this.onBoost,
    required this.onMarkSold,
  });

  final FeedState state;
  final ScrollController scrollController;
  final ValueChanged<Load> onRequest;
  final ValueChanged<Load> onReport;
  final ValueChanged<Load> onDelete;
  final ValueChanged<Load> onOffer;
  final ValueChanged<Load> onBoost;
  final ValueChanged<Load> onMarkSold;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case FeedStatus.initial:
      case FeedStatus.loading:
        return const FeedSkeleton();
      case FeedStatus.error:
        return ErrorView(
          message: state.errorMessage ?? 'Could not load the feed.',
          onRetry: () => context.read<FeedCubit>().load(),
        );
      case FeedStatus.empty:
        return RefreshIndicator(
          onRefresh: () => context.read<FeedCubit>().refresh(),
          child: ListView(
            children: const [
              SizedBox(height: 120),
              EmptyView(
                title: 'No posts yet',
                subtitle: 'Pull to refresh, or check back soon.',
                icon: Icons.photo_library_outlined,
              ),
            ],
          ),
        );
      case FeedStatus.loaded:
        // Interleave an ad after every AdConfig.postsBetweenAds posts. This is a
        // pure view-layer concern: FeedCubit holds only posts, so pagination and
        // pull-to-refresh stay unaffected by ads.
        final entries = _buildEntries(state.loads);
        return RefreshIndicator(
          onRefresh: () => context.read<FeedCubit>().refresh(),
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: entries.length + (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= entries.length) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final entry = entries[index];
              if (entry is _AdEntry) {
                return FeedAdSlot(key: ValueKey('ad_${entry.slot}'));
              }
              final load = (entry as _PostEntry).load;
              return PostCard(
                key: ValueKey('post_${load.id}'),
                load: load,
                onRequest: () => onRequest(load),
                onReport: () => onReport(load),
                onDelete: () => onDelete(load),
                onOffer: () => onOffer(load),
                onTap: () => context.push(AppRoutes.postDetail, extra: load),
                onBoost: () => onBoost(load),
                onMarkSold: () => onMarkSold(load),
                onEditDeferred: () =>
                    context.push(AppRoutes.createPost, extra: load),
              );
            },
          ),
        );
    }
  }
}

class _GradientWordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => context.nexveero.primaryGradient.createShader(rect),
      child: Text(
        'Nexveero',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}

/// A row in the feed list: either a post or an injected ad slot.
sealed class _FeedEntry {
  const _FeedEntry();
}

class _PostEntry extends _FeedEntry {
  const _PostEntry(this.load);
  final Load load;
}

class _AdEntry extends _FeedEntry {
  const _AdEntry(this.slot);
  final int slot;
}

/// Builds the interleaved list: one ad after every [AdConfig.postsBetweenAds]
/// posts, but never before [AdConfig.minPostsBeforeFirstAd] posts are shown.
/// A trailing ad is not appended after the final partial group.
List<_FeedEntry> _buildEntries(List<Load> loads) {
  final entries = <_FeedEntry>[];
  final n = AdConfig.postsBetweenAds;
  for (var i = 0; i < loads.length; i++) {
    entries.add(_PostEntry(loads[i]));
    final postsShown = i + 1;
    final isGroupEnd = postsShown % n == 0;
    final pastFirstAdFloor = postsShown >= AdConfig.minPostsBeforeFirstAd;
    final hasMorePosts = i < loads.length - 1;
    if (isGroupEnd && pastFirstAdFloor && hasMorePosts) {
      entries.add(_AdEntry(i ~/ n));
    }
  }
  return entries;
}
