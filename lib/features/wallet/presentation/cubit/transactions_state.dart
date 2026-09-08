part of 'transactions_cubit.dart';

enum TxStatus { initial, loading, loaded, empty, error }

class TransactionsState extends Equatable {
  const TransactionsState({
    this.status = TxStatus.initial,
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final TxStatus status;
  final List<WalletTransaction> items;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  TransactionsState copyWith({
    TxStatus? status,
    List<WalletTransaction>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
  }) {
    return TransactionsState(
      status: status ?? this.status,
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, items, page, hasMore, isLoadingMore, errorMessage];
}
