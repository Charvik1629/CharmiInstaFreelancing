import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/load.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../feed/domain/repositories/feed_repository.dart';
import '../../../feed/presentation/cubit/feed_cubit.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../../feed/presentation/widgets/report_sheet.dart';
import '../../../offers/presentation/widgets/make_offer_sheet.dart';

/// Marketplace / Business feed (design "Business Feed"). Reuses [FeedCubit]
/// pinned to the "business" post type, and the same [PostCard].
class MarketplacePage extends StatelessWidget {
  const MarketplacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FeedCubit(sl<FeedRepository>(), fixedSlug: 'business')..load(),
      child: const _MarketplaceView(),
    );
  }
}

class _MarketplaceView extends StatefulWidget {
  const _MarketplaceView();

  @override
  State<_MarketplaceView> createState() => _MarketplaceViewState();
}

class _MarketplaceViewState extends State<_MarketplaceView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
        context.read<FeedCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _offer(Load load) async {
    final offer = await MakeOfferSheet.show(context,
        loadId: load.id, loadTitle: load.title);
    if (offer != null && mounted) AppOverlays.snack(context, 'Offer sent');
  }

  Future<void> _request(Load load) async {
    final id = await context.read<FeedCubit>().request(load);
    if (!mounted) return;
    AppOverlays.snack(
        context, id != null ? 'Request sent — chat opened' : 'Could not send request');
  }

  Future<void> _report(Load load) async {
    final reason = await ReportSheet.show(context);
    if (reason == null || !mounted) return;
    final result = await context.read<FeedCubit>().report(load, reason);
    if (!mounted) return;
    AppOverlays.snack(context,
        result is Success ? 'Report submitted' : 'Could not submit report');
  }

  Future<void> _delete(Load load) async {
    final ok = await AppOverlays.confirm(context,
        title: 'Delete post?', confirmLabel: 'Delete', destructive: true);
    if (!ok || !mounted) return;
    await context.read<FeedCubit>().delete(load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'New listing',
            onPressed: () => context.push(AppRoutes.createPost),
          ),
        ],
      ),
      body: BlocBuilder<FeedCubit, FeedState>(
        builder: (context, state) {
          switch (state.status) {
            case FeedStatus.loading:
            case FeedStatus.initial:
              return const LoadingView();
            case FeedStatus.error:
              return ErrorView(
                message: state.errorMessage ?? 'Could not load the marketplace',
                onRetry: () => context.read<FeedCubit>().load(),
              );
            case FeedStatus.empty:
              return const EmptyView(
                title: 'No listings yet',
                subtitle: 'Business posts will show up here.',
                icon: Icons.storefront_outlined,
              );
            case FeedStatus.loaded:
              return RefreshIndicator(
                onRefresh: () => context.read<FeedCubit>().refresh(),
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: state.loads.length + (state.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= state.loads.length) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final load = state.loads[i];
                    return PostCard(
                      key: ValueKey('mkt_${load.id}'),
                      load: load,
                      onRequest: () => _request(load),
                      onReport: () => _report(load),
                      onDelete: () => _delete(load),
                      onOffer: () => _offer(load),
                      onTap: () => context.push(AppRoutes.postDetail, extra: load),
                    );
                  },
                ),
              );
          }
        },
      ),
    );
  }
}
