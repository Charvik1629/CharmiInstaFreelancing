import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/load.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../feed/domain/repositories/feed_repository.dart';
import '../../../feed/presentation/cubit/feed_cubit.dart';
import '../../../feed/presentation/widgets/ask_question_sheet.dart';
import '../../../feed/presentation/widgets/boost_confirm_dialog.dart';
import '../../../feed/presentation/widgets/feed_ad_slot.dart';
import '../../../feed/presentation/widgets/report_sheet.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../widgets/business_options_sheet.dart';
import '../widgets/business_post_card.dart';

/// The **Business** tab (design "Business Feed", HTML 991–1128): a feed of
/// business posts (`/loads` post_type=Business) with Share/Report actions and
/// Google "Sponsored" ad cards interspersed. Header uses the gradient
/// "Business" wordmark.
class BusinessFeedPage extends StatelessWidget {
  const BusinessFeedPage({super.key, this.reselect});

  /// Bumped by the shell when the Business tab is tapped while already active →
  /// refresh + scroll to top.
  final ValueListenable<int>? reselect;

  /// Show one sponsored slot after every N business posts.
  static const int _postsBetweenAds = 2;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FeedCubit(sl<FeedRepository>(), fixedSlug: 'business')..load(),
      child: _BusinessFeedView(reselect: reselect),
    );
  }
}

class _BusinessFeedView extends StatefulWidget {
  const _BusinessFeedView({this.reselect});

  final ValueListenable<int>? reselect;

  @override
  State<_BusinessFeedView> createState() => _BusinessFeedViewState();
}

class _BusinessFeedViewState extends State<_BusinessFeedView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
        context.read<FeedCubit>().loadMore();
      }
    });
    widget.reselect?.addListener(_onReselect);
  }

  /// Business tab re-tapped: jump to top, then refresh.
  void _onReselect() {
    if (!mounted) return;
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    context.read<FeedCubit>().refresh();
  }

  /// Open the composer; on a successful publish, reload so the new post shows.
  Future<void> _createPost() async {
    final created = await context.push<Load>(AppRoutes.createPost);
    if (created == null || !mounted) return;
    await context.read<FeedCubit>().refresh();
    if (!mounted) return;
    AppOverlays.snack(context, 'Post published');
  }

  @override
  void dispose() {
    widget.reselect?.removeListener(_onReselect);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _report(Load load) async {
    final reason = await ReportSheet.show(context, subtitle: load.title);
    if (reason == null || !mounted) return;
    final result = await context.read<FeedCubit>().report(load, reason);
    if (!mounted) return;
    AppOverlays.snack(context,
        result.isSuccess ? 'Report submitted' : 'Could not submit report');
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
    final text = [
      load.title,
      if (by != null) 'by $by',
      if ((load.shareUrl ?? '').isNotEmpty) load.shareUrl,
    ].whereType<String>().join(' ');
    await SharePlus.instance.share(ShareParams(text: text));
  }

  // ⋯ is owner-only (the card hides it for other users, who use the inline
  // Ask / Share / Report row instead).
  Future<void> _more(Load load) async {
    final choice = await BusinessOptionsSheet.show(context);
    if (choice == null || !mounted) return;
    switch (choice) {
      case BusinessOption.edit:
        // Open the composer pre-filled with this post, then refresh on save.
        final updated = await context.push<Load>(AppRoutes.createPost, extra: load);
        if (updated == null || !mounted) return;
        await context.read<FeedCubit>().refresh();
      case BusinessOption.boost:
        await _boost(load);
    }
  }

  Future<void> _boost(Load load) async {
    final wallet = (await sl<WalletRepository>().getWallet()).valueOrNull;
    if (!mounted) return;
    final ok = await BoostConfirmDialog.show(context,
        cost: wallet?.boostCost ?? 20, balance: wallet?.creditBalance ?? 0);
    if (!ok || !mounted) return;
    final result = await context.read<FeedCubit>().boost(load);
    if (!mounted) return;
    AppOverlays.snack(context,
        result.isSuccess ? 'Post boosted 🚀' : 'Could not boost');
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
        title: const _GradientWordmark('Business'),
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
          _SearchBar(onTap: () => context.push(AppRoutes.businessDirectory)),
          Expanded(
            child: BlocBuilder<FeedCubit, FeedState>(
              builder: (context, state) => _Body(
                state: state,
                scroll: _scroll,
                onShare: _share,
                onReport: _report,
                onAsk: _ask,
                onMore: _more,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.scroll,
    required this.onShare,
    required this.onReport,
    required this.onAsk,
    required this.onMore,
  });
  final FeedState state;
  final ScrollController scroll;
  final ValueChanged<Load> onShare;
  final ValueChanged<Load> onReport;
  final ValueChanged<Load> onAsk;
  final ValueChanged<Load> onMore;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case FeedStatus.initial:
      case FeedStatus.loading:
        return const FeedSkeleton();
      case FeedStatus.error:
        return ErrorView(
          message: state.errorMessage ?? 'Could not load the business feed.',
          onRetry: () => context.read<FeedCubit>().load(),
        );
      case FeedStatus.empty:
        return RefreshIndicator(
          onRefresh: () => context.read<FeedCubit>().refresh(),
          child: ListView(
            children: const [
              SizedBox(height: 120),
              EmptyView(
                title: 'No business posts yet',
                subtitle: 'Business updates appear here. Pull to refresh.',
                icon: Icons.storefront_outlined,
              ),
            ],
          ),
        );
      case FeedStatus.loaded:
        final entries = <Object>[];
        for (var i = 0; i < state.loads.length; i++) {
          entries.add(state.loads[i]);
          final isLast = i == state.loads.length - 1;
          if (!isLast && (i + 1) % BusinessFeedPage._postsBetweenAds == 0) {
            entries.add(_AdMarker(i));
          }
        }
        return RefreshIndicator(
          onRefresh: () => context.read<FeedCubit>().refresh(),
          child: ListView.builder(
            controller: scroll,
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
              if (entry is _AdMarker) {
                return FeedAdSlot(key: ValueKey('biz_ad_${entry.slot}'));
              }
              final load = entry as Load;
              return BusinessPostCard(
                onAsk: () => onAsk(load),
                key: ValueKey('biz_post_${load.id}'),
                load: load,
                onShare: () => onShare(load),
                onReport: () => onReport(load),
                onMore: () => onMore(load),
              );
            },
          ),
        );
    }
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: nex.elevated,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: nex.iconInactive),
              const SizedBox(width: AppSpacing.sm),
              Text('Search products, tags, business…',
                  style: TextStyle(color: nex.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marks where a sponsored slot sits in the flattened business-feed list.
class _AdMarker {
  const _AdMarker(this.slot);
  final int slot;
}

class _GradientWordmark extends StatelessWidget {
  const _GradientWordmark(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) =>
          context.nexveero.primaryGradient.createShader(rect),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .headlineMedium
            ?.copyWith(color: Colors.white),
      ),
    );
  }
}
