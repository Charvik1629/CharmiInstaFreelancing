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

/// Offers inbox (design "Offers" / "Offer Listing") — All / Received / Sent
/// filter chips, a search field, and offer rows with a price pill + Chat action.
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
  String _query = '';

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

  void _setTab(OfferTag tag) => context.read<OffersListCubit>().setTab(tag);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: Column(
        children: [
          // Search field (design: "Search offers…") — filters loaded offers.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: AppTextField(
              hint: 'Search offers…',
              prefixIcon: Icons.search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          // All / Received / Sent filter chips.
          BlocBuilder<OffersListCubit, OffersListState>(
            buildWhen: (p, c) => p.tag != c.tag,
            builder: (context, state) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  AppChip(
                    label: 'All',
                    selected: state.tag == OfferTag.all,
                    onTap: () => _setTab(OfferTag.all),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppChip(
                    label: 'Received',
                    selected: state.tag == OfferTag.received,
                    onTap: () => _setTab(OfferTag.received),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppChip(
                    label: 'Sent',
                    selected: state.tag == OfferTag.sent,
                    onTap: () => _setTab(OfferTag.sent),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: BlocBuilder<OffersListCubit, OffersListState>(
              builder: (context, state) {
                switch (state.status) {
                  case OffersStatus.loading:
                  case OffersStatus.initial:
                    return const ListSkeleton();
                  case OffersStatus.error:
                    return ErrorView(
                      message: state.errorMessage ?? 'Could not load offers',
                      onRetry: () => context.read<OffersListCubit>().load(),
                    );
                  case OffersStatus.empty:
                    return EmptyView(
                      title: _emptyTitle(state.tag),
                      subtitle: _emptySubtitle(state.tag),
                      icon: Icons.local_offer_outlined,
                    );
                  case OffersStatus.loaded:
                    final offers = _query.isEmpty
                        ? state.offers
                        : state.offers.where(_matchesQuery).toList();
                    if (offers.isEmpty) {
                      return const EmptyView(
                        title: 'No matches',
                        subtitle: 'No offers match your search.',
                        icon: Icons.search_off,
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () => context.read<OffersListCubit>().refresh(),
                      child: ListView.separated(
                        controller: _scroll,
                        itemCount:
                            offers.length + (state.isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: 76,
                            color: context.nexveero.border),
                        itemBuilder: (context, i) {
                          if (i >= offers.length) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _OfferRow(offer: offers[i]);
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

  bool _matchesQuery(Offer o) {
    final hay = [
      o.otherPartyName ?? '',
      o.body ?? '',
      o.loadTitle ?? '',
    ].join(' ').toLowerCase();
    return hay.contains(_query);
  }

  String _emptyTitle(OfferTag tag) => switch (tag) {
        OfferTag.received => 'No offers received',
        OfferTag.sent => 'No offers sent',
        OfferTag.all => 'No offers yet',
      };

  String _emptySubtitle(OfferTag tag) => switch (tag) {
        OfferTag.received => 'Offers on your posts will appear here.',
        OfferTag.sent => 'Offers you make will appear here.',
        OfferTag.all => 'Offers you send or receive will appear here.',
      };
}

/// Offer row (design 2043–2079): avatar · name + time · message, then a price
/// pill on the left and a Chat button on the right.
class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer});
  final Offer offer;

  void _openChat(BuildContext context) {
    if (offer.conversationId == null) return;
    context.push(
      AppRoutes.chatThread,
      extra: Conversation(
        id: offer.conversationId!,
        type: ConversationType.direct,
        title: offer.otherPartyName ?? 'Someone',
        avatarUrl: offer.otherPartyAvatar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final nex = context.nexveero;
    final name = offer.otherPartyName ?? 'Someone';
    final message = (offer.body ?? '').isNotEmpty
        ? offer.body!
        : (offer.loadTitle ?? '').isNotEmpty
            ? 'on “${offer.loadTitle}”'
            : '';
    return InkWell(
      onTap: offer.conversationId == null ? null : () => _openChat(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(
                name: name,
                imageUrl: MediaUrl.resolve(offer.otherPartyAvatar),
                size: 44),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: texts.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      if (offer.createdAt != null)
                        Text(offer.createdAt!.timeAgo,
                            style: texts.labelSmall
                                ?.copyWith(color: nex.textSecondary)),
                    ],
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: texts.bodySmall
                            ?.copyWith(color: nex.textSecondary)),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (offer.priceFormatted != null)
                        _PricePill(text: '₹ ${offer.priceFormatted}')
                      else
                        const SizedBox.shrink(),
                      if (offer.conversationId != null)
                        _ChatButton(onTap: () => _openChat(context)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Price pill (design: tonal chip, primary text).
class _PricePill extends StatelessWidget {
  const _PricePill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(text,
          style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontSize: 11.5,
              fontWeight: FontWeight.w700)),
    );
  }
}

/// Tonal "Chat" action (design: chat_bubble icon + label).
class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 16, color: scheme.onPrimaryContainer),
              const SizedBox(width: 5),
              Text('Chat',
                  style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
