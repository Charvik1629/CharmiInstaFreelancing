import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../data/datasources/offers_remote_data_source.dart';
import '../../domain/entities/offer.dart';
import '../../domain/repositories/offers_repository.dart';

part 'offers_list_state.dart';

/// Drives the Offers inbox — Received / Sent tabs (GET /offers?tag=…) with
/// paging and pull-to-refresh.
class OffersListCubit extends Cubit<OffersListState> {
  OffersListCubit(this._repository) : super(const OffersListState());

  final OffersRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: OffersStatus.loading, page: 1, hasMore: true));
    final result = await _repository.getOffers(tag: state.tag, page: 1);
    switch (result) {
      case Success(value: final res):
        emit(state.copyWith(
          status: res.items.isEmpty ? OffersStatus.empty : OffersStatus.loaded,
          offers: res.items,
          page: 1,
          hasMore: res.meta.hasMore && res.items.isNotEmpty,
        ));
      case Err(failure: final f):
        emit(state.copyWith(status: OffersStatus.error, errorMessage: f.message));
    }
  }

  Future<void> refresh() => load();

  Future<void> setTab(OfferTag tag) async {
    if (tag == state.tag) return;
    emit(state.copyWith(tag: tag, offers: const [], status: OffersStatus.loading));
    await load();
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.status != OffersStatus.loaded) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    final next = state.page + 1;
    final result = await _repository.getOffers(tag: state.tag, page: next);
    switch (result) {
      case Success(value: final res):
        emit(state.copyWith(
          offers: [...state.offers, ...res.items],
          page: next,
          hasMore: res.meta.hasMore && res.items.isNotEmpty,
          isLoadingMore: false,
        ));
      case Err():
        emit(state.copyWith(isLoadingMore: false, hasMore: false));
    }
  }
}
