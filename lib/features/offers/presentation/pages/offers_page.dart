import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../chat/domain/entities/conversation.dart';
import '../../data/datasources/offers_remote_data_source.dart';
import '../../domain/entities/offer.dart';
import '../cubit/offers_list_cubit.dart';

/// Offers inbox (design "Offers" / "Offer Listing") — Received and Sent tabs.
class OffersPage extends StatelessWidget {
  const OffersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OffersListCubit>()..load(),
      child: const _OffersView(),
    );
  }
}

class _OffersView extends StatefulWidget {
  const _OffersView();

  @override
  State<_OffersView> createState() => _OffersViewState();
}

class _OffersViewState extends State<_OffersView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        context.read<OffersListCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: BlocBuilder<OffersListCubit, OffersListState>(
              buildWhen: (p, c) => p.tag != c.tag,
              builder: (context, state) => AppSegmented(
                segments: const ['Received', 'Sent'],
                selectedIndex: state.tag == OfferTag.received ? 0 : 1,
                onChanged: (i) => context
                    .read<OffersListCubit>()
                    .setTab(i == 0 ? OfferTag.received : OfferTag.sent),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<OffersListCubit, OffersListState>(
              builder: (context, state) {
                switch (state.status) {
                  case OffersStatus.loading:
                  case OffersStatus.initial:
                    return const LoadingView();
                  case OffersStatus.error:
                    return ErrorView(
                      message: state.errorMessage ?? 'Could not load offers',
                      onRetry: () => context.read<OffersListCubit>().load(),
                    );
                  case OffersStatus.empty:
                    return EmptyView(
                      title: state.tag == OfferTag.received
                          ? 'No offers received'
                          : 'No offers sent',
                      subtitle: state.tag == OfferTag.received
                          ? 'Offers on your posts will appear here.'
                          : 'Offers you make will appear here.',
                      icon: Icons.local_offer_outlined,
                    );
                  case OffersStatus.loaded:
                    return RefreshIndicator(
                      onRefresh: () => context.read<OffersListCubit>().refresh(),
                      child: ListView.separated(
                        controller: _scroll,
                        itemCount: state.offers.length + (state.isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, indent: 76, color: context.nexveero.border),
                        itemBuilder: (context, i) {
                          if (i >= state.offers.length) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _OfferRow(offer: state.offers[i]);
                        },
                      ),
                    );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer});
  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final name = offer.otherPartyName ?? 'Someone';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      leading: AppAvatar(
          name: name, imageUrl: MediaUrl.resolve(offer.otherPartyAvatar), size: 44),
      title: Row(
        children: [
          Expanded(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (offer.priceFormatted != null)
            Text('₹${offer.priceFormatted}',
                style: texts.titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((offer.loadTitle ?? '').isNotEmpty)
            Text('on “${offer.loadTitle}”',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: texts.bodySmall?.copyWith(color: context.nexveero.textSecondary)),
          if ((offer.body ?? '').isNotEmpty)
            Text(offer.body!, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (offer.createdAt != null)
            Text(offer.createdAt!.timeAgo,
                style: texts.labelSmall?.copyWith(color: context.nexveero.textSecondary)),
        ],
      ),
      isThreeLine: true,
      onTap: offer.conversationId == null
          ? null
          : () => context.push(
                AppRoutes.chatThread,
                extra: Conversation(
                  id: offer.conversationId!,
                  type: ConversationType.direct,
                  title: name,
                  avatarUrl: offer.otherPartyAvatar,
                ),
              ),
    );
  }
}
