part of 'feed_cubit.dart';

enum FeedStatus { initial, loading, loaded, empty, error }

/// Feed filter tabs (design: All / Buy / Sell). Maps to the `post_type` query
/// param; `all` sends no filter.
enum FeedFilter {
  all(null, 'All'),
  buy('buy', 'Buy'),
  sell('sell', 'Sell');

  const FeedFilter(this.slug, this.label);
  final String? slug;
  final String label;
}

class FeedState extends Equatable {
  const FeedState({
    this.status = FeedStatus.initial,
    this.loads = const [],
    this.filter = FeedFilter.all,
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final FeedStatus status;
  final List<Load> loads;
  final FeedFilter filter;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  FeedState copyWith({
    FeedStatus? status,
    List<Load>? loads,
    FeedFilter? filter,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
  }) {
    return FeedState(
      status: status ?? this.status,
      loads: loads ?? this.loads,
      filter: filter ?? this.filter,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, loads, filter, page, hasMore, isLoadingMore, errorMessage];
}
