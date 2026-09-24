import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

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
import '../widgets/ask_question_sheet.dart';
import '../widgets/boost_confirm_dialog.dart';
import '../widgets/request_success_sheet.dart';
import '../widgets/post_card.dart';
import '../widgets/report_sheet.dart';

/// The home feed. Lists posts (loads) with filters, pull-to-refresh and
/// infinite scroll, and handles the per-post actions.
class FeedPage extends StatelessWidget {
  const FeedPage({super.key, this.reselect});

  /// Bumped by the shell when the Home tab is tapped while already active →
  /// refresh + scroll to top.
  final ValueListenable<int>? reselect;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<FeedCubit>()..load(),
      child: _FeedView(reselect: reselect),
    );
  }
}

class _FeedView extends StatefulWidget {
  const _FeedView({this.reselect});

  final ValueListenable<int>? reselect;

  @override
  State<_FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<_FeedView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.reselect?.addListener(_onReselect);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      context.read<FeedCubit>().loadMore();
    }
  }

  /// Home tab re-tapped: jump to top, then refresh the feed.
  void _onReselect() {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    context.read<FeedCubit>().refresh();
  }

  @override
  void dispose() {
    widget.reselect?.removeListener(_onReselect);
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

  Future<void> _ask(Load load) async {
    final body = await AskQuestionSheet.show(context, subtitle: load.title);
    if (body == null || body.isEmpty || !mounted) return;
    final result = await context.read<FeedCubit>().ask(load, body);
    if (!mounted) return;
    AppOverlays.snack(context,
        result.isSuccess ? 'Question sent' : 'Could not send question');
  }

  Future<void> _share(Load load) async {
    final by = load.author?.name;
    // Share the post's canonical link (API share_url) — not just plain text.
    final text = [
      load.title,
      if (by != null) 'by $by',
      if ((load.shareUrl ?? '').isNotEmpty) load.shareUrl,
    ].whereType<String>().join(' ');
    await SharePlus.instance.share(ShareParams(text: text));
  }

  /// Opens the existing 1:1 chat for a post the viewer already requested.
  void _directMessage(Load load) {
    final id = load.conversationId;
    if (id == null) return;
    context.push(
      AppRoutes.chatThread,
      extra: Conversation(
        id: id,
        type: ConversationType.direct,
        title: load.author?.name ?? 'Chat',
        avatarUrl: load.author?.avatarUrl,
        peerId: load.author?.id,
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
                onAsk: _ask,
                onShare: _share,
                onDirectMessage: _directMessage,
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
    required this.onAsk,
    required this.onShare,
    required this.onDirectMessage,
  });

  final FeedState state;
  final ScrollController scrollController;
  final ValueChanged<Load> onRequest;
  final ValueChanged<Load> onReport;
  final ValueChanged<Load> onDelete;
  final ValueChanged<Load> onOffer;
  final ValueChanged<Load> onBoost;
  final ValueChanged<Load> onMarkSold;
  final ValueChanged<Load> onAsk;
  final ValueChanged<Load> onShare;
  final ValueChanged<Load> onDirectMessage;

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
        // No ads on the Home feed — AdMob is restricted to the Business feed.
        return RefreshIndicator(
          onRefresh: () => context.read<FeedCubit>().refresh(),
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: state.loads.length + (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.loads.length) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final load = state.loads[index];
              return PostCard(
                key: ValueKey('post_${load.id}'),
                load: load,
                onRequest: () => onRequest(load),
                onReport: () => onReport(load),
                onDelete: () => onDelete(load),
                onOffer: () => onOffer(load),
                onAsk: () => onAsk(load),
                onShare: () => onShare(load),
                onDirectMessage: () => onDirectMessage(load),
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
        // Design "Home Feed" wordmark is the section label "Post" (the Business
        // feed likewise uses "Business"), rendered in the primary gradient.
        'Post',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}

