import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../feed/presentation/widgets/feed_ad_slot.dart';
import '../../domain/entities/business_post.dart';
import '../../domain/repositories/business_repository.dart';
import '../cubit/business_feed_cubit.dart';
import '../widgets/business_post_card.dart';

/// The **Business** tab (design "Business Feed", HTML 991–1128): a feed of
/// business posts (Share / Report only) with Google "Sponsored" ad cards
/// interspersed. Header uses the gradient "Business" wordmark.
class BusinessFeedPage extends StatelessWidget {
  const BusinessFeedPage({super.key});

  /// Show one sponsored slot after every N business posts.
  static const int _postsBetweenAds = 2;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BusinessFeedCubit(sl<BusinessRepository>())..load(),
      child: const _BusinessFeedView(),
    );
  }
}

class _BusinessFeedView extends StatelessWidget {
  const _BusinessFeedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.add_box_outlined),
          tooltip: 'Create post',
          onPressed: () => context.push(AppRoutes.createPost),
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
          _SearchBar(onTap: () => context.push(AppRoutes.search)),
          Expanded(
            child: BlocBuilder<BusinessFeedCubit, BusinessFeedState>(
              builder: (context, state) => _Body(state: state),
            ),
          ),
        ],
      ),
    );
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

class _Body extends StatelessWidget {
  const _Body({required this.state});
  final BusinessFeedState state;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case BusinessFeedStatus.initial:
      case BusinessFeedStatus.loading:
        return const LoadingView();
      case BusinessFeedStatus.error:
        return ErrorView(
          message: state.errorMessage ?? 'Could not load the business feed.',
          onRetry: () => context.read<BusinessFeedCubit>().load(),
        );
      case BusinessFeedStatus.gated:
        return const EmptyView(
          title: 'Business feed is coming soon',
          subtitle:
              'Businesses will share updates here, with sponsored placements '
              'interspersed. This turns on once the backend is ready.',
          icon: Icons.storefront_outlined,
        );
      case BusinessFeedStatus.empty:
        return RefreshIndicator(
          onRefresh: () => context.read<BusinessFeedCubit>().refresh(),
          child: ListView(
            children: const [
              SizedBox(height: 120),
              EmptyView(
                title: 'No business posts yet',
                subtitle: 'Pull to refresh, or check back soon.',
                icon: Icons.storefront_outlined,
              ),
            ],
          ),
        );
      case BusinessFeedStatus.loaded:
        // Flatten posts + interspersed sponsored slots into one entry list so
        // indexing stays simple and correct.
        final entries = <Object>[];
        for (var i = 0; i < state.posts.length; i++) {
          entries.add(state.posts[i]);
          final isLast = i == state.posts.length - 1;
          if (!isLast && (i + 1) % BusinessFeedPage._postsBetweenAds == 0) {
            entries.add(_AdMarker(i));
          }
        }
        return RefreshIndicator(
          onRefresh: () => context.read<BusinessFeedCubit>().refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              if (entry is _AdMarker) {
                return FeedAdSlot(key: ValueKey('biz_ad_${entry.slot}'));
              }
              final post = entry as BusinessPost;
              return BusinessPostCard(
                key: ValueKey('biz_post_${post.id}'),
                post: post,
                onShare: () => AppOverlays.snack(
                    context, 'Sharing arrives with the share sheet.'),
                onReport: () => AppOverlays.snack(context, 'Report received.'),
              );
            },
          ),
        );
    }
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
