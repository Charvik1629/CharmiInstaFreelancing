part of 'offers_list_cubit.dart';

enum OffersStatus { initial, loading, loaded, empty, error }

class OffersListState extends Equatable {
  const OffersListState({
    this.status = OffersStatus.initial,
    this.tag = OfferTag.all,
    this.offers = const [],
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final OffersStatus status;
  final OfferTag tag;
  final List<Offer> offers;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  OffersListState copyWith({
    OffersStatus? status,
    OfferTag? tag,
    List<Offer>? offers,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
  }) {
    return OffersListState(
      status: status ?? this.status,
      tag: tag ?? this.tag,
      offers: offers ?? this.offers,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, tag, offers, page, hasMore, isLoadingMore, errorMessage];
}
