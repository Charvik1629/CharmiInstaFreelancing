import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/repositories/wallet_repository.dart';

part 'transactions_state.dart';

/// Paginated wallet ledger for the Transactions screen.
class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit(this._repository) : super(const TransactionsState());

  final WalletRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: TxStatus.loading, page: 1, hasMore: true));
    final result = await _repository.getTransactions(page: 1);
    switch (result) {
      case Success(value: final res):
        emit(state.copyWith(
          status: res.items.isEmpty ? TxStatus.empty : TxStatus.loaded,
          items: res.items,
          page: 1,
          hasMore: res.meta.hasMore && res.items.isNotEmpty,
        ));
      case Err(failure: final f):
        emit(state.copyWith(status: TxStatus.error, errorMessage: f.message));
    }
  }

  Future<void> refresh() => load();

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.status != TxStatus.loaded) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    final next = state.page + 1;
    final result = await _repository.getTransactions(page: next);
    switch (result) {
      case Success(value: final res):
        emit(state.copyWith(
          items: [...state.items, ...res.items],
          page: next,
          hasMore: res.meta.hasMore && res.items.isNotEmpty,
          isLoadingMore: false,
        ));
      case Err():
        emit(state.copyWith(isLoadingMore: false, hasMore: false));
    }
  }
}
