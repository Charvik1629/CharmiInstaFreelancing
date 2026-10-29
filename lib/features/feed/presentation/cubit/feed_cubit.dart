import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/load.dart';
import '../../../../core/realtime/socket_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/feed_repository.dart';

part 'feed_state.dart';

/// Drives the feed: first-page load, pull-to-refresh, infinite-scroll paging,
/// filter switching, and per-item actions. Ads are injected by the view layer
/// (Module 6), not here, so pagination stays clean.
class FeedCubit extends Cubit<FeedState> {
  FeedCubit(this._repository, {this.fixedSlug}) : super(const FeedState()) {
    _listenReconnect();
  }

  final FeedRepository _repository;

  StreamSubscription<void>? _connectedSub;
  Timer? _searchDebounce;

  /// Live in-feed search text (server `q`). Empty → no filter.
  String _query = '';
  String? get _q => _query.isEmpty ? null : _query;

  /// Debounced search: filters the feed server-side via `q` without leaving the
  /// screen (design: typing in the feed search bar narrows the feed in place).
  void setSearch(String q) {
    _query = q.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), load);
  }

  /// The feed has no live "new post" push, so on (re)connect — e.g. returning
  /// from background — refetch page 1 so posts others created meanwhile appear
  /// without a manual pull-to-refresh.
  void _listenReconnect() {
    if (!sl.isRegistered<SocketService>()) return;
    _connectedSub = sl<SocketService>().connected.listen((_) {
      if (state.status == FeedStatus.loaded || state.status == FeedStatus.empty) {
        refresh();
      }
    });
  }

  @override
  Future<void> close() {
    _connectedSub?.cancel();
    _searchDebounce?.cancel();
    return super.close();
  }

  /// When set (e.g. Marketplace = "business"), the cubit always loads this
  /// post-type and ignores the filter chips.
  final String? fixedSlug;

  /// The slug actually queried — the fixed one, or the active filter's.
  String? get _slug => fixedSlug ?? state.filter.slug;

  /// Initial load (or reload after an error). Shows the full-screen spinner.
  Future<void> load() async {
    emit(state.copyWith(status: FeedStatus.loading, page: 1, hasMore: true));
    final result = await _repository.getLoads(page: 1, postTypeSlug: _slug, q: _q);
    if (isClosed) return; // navigated away mid-load (e.g. an auth bounce)
    switch (result) {
      case Success(value: final res):
        emit(state.copyWith(
          status: res.items.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
          loads: res.items,
          page: 1,
          hasMore: res.meta.hasMore && res.items.isNotEmpty,
        ));
      case Err(failure: final f):
        emit(state.copyWith(status: FeedStatus.error, errorMessage: f.message));
    }
  }

  /// Pull-to-refresh: reloads page 1 without hiding the current list.
  Future<void> refresh() async {
    final result = await _repository.getLoads(page: 1, postTypeSlug: _slug, q: _q);
    switch (result) {
      case Success(value: final res):
        emit(state.copyWith(
          status: res.items.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
          loads: res.items,
          page: 1,
          hasMore: res.meta.hasMore && res.items.isNotEmpty,
        ));
      case Err(failure: final f):
        // Keep showing the stale list; surface the error to the UI separately.
        emit(state.copyWith(errorMessage: f.message));
    }
  }

  /// Loads the next page for infinite scroll. No-ops while already loading or
  /// when there is nothing more.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.status != FeedStatus.loaded) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    final next = state.page + 1;
    final result = await _repository.getLoads(page: next, postTypeSlug: _slug, q: _q);
    switch (result) {
      case Success(value: final res):
        emit(state.copyWith(
          loads: [...state.loads, ...res.items],
          page: next,
          hasMore: res.meta.hasMore && res.items.isNotEmpty,
          isLoadingMore: false,
        ));
      case Err(failure: final f):
        // Stop paging on error but keep what we have.
        emit(state.copyWith(isLoadingMore: false, hasMore: false, errorMessage: f.message));
    }
  }

  Future<void> setFilter(FeedFilter filter) async {
    if (filter == state.filter) return;
    emit(state.copyWith(filter: filter, loads: const [], status: FeedStatus.loading));
    await load();
  }

  /// Requests a post (opens a chat). Returns the conversationId on success.
  /// Optimistically flips the card to "Requested".
  Future<int?> request(Load load) async {
    final result = await _repository.requestLoad(load.id);
    switch (result) {
      case Success(value: final conversationId):
        _replace(load.copyWith(viewerHasRequested: true, conversationId: conversationId));
        return conversationId;
      case Err():
        return null;
    }
  }

  /// Flips a card to "View offer" in place after the viewer makes (or is found
  /// to already have) an offer, recording the offer's chat thread id.
  void markOffered(Load load, int? conversationId) {
    _replace(load.copyWith(
      viewerHasOffer: true,
      offerConversationId: conversationId,
    ));
  }

  Future<Result<void>> report(Load load, String reason) =>
      _repository.reportLoad(load.id, reason);

  /// Asks a question about a post (POST /loads/{id}/questions).
  Future<Result<void>> ask(Load load, String body) =>
      _repository.askQuestion(load.id, body);

  /// Boosts an owned post. On success flips the card to "Boosted" in place
  /// (keeps the full card data rather than the partial boost response).
  Future<Result<Load>> boost(Load load) async {
    final result = await _repository.boostLoad(load.id);
    if (result.isSuccess) {
      _replace(load.copyWith(isBoosted: true, canBoost: false));
    }
    return result;
  }

  /// Marks an owned post as sold. On success replaces the card with the updated
  /// (closed) load in place.
  Future<Result<Load>> markSold(Load load) async {
    final result = await _repository.markSold(load.id);
    if (result case Success(value: final updated)) _replace(updated);
    return result;
  }

  /// Deletes an owned post and removes it from the list on success.
  Future<Result<void>> delete(Load load) async {
    final result = await _repository.deleteLoad(load.id);
    if (result.isSuccess) {
      final remaining = state.loads.where((l) => l.id != load.id).toList();
      emit(state.copyWith(
        loads: remaining,
        status: remaining.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
      ));
    }
    return result;
  }

  /// Inserts a freshly created post at the top of the feed so the author sees
  /// it immediately, without waiting for a refresh. Flips an empty feed to
  /// loaded.
  void prepend(Load load) {
    emit(state.copyWith(
      loads: [load, ...state.loads],
      status: FeedStatus.loaded,
    ));
  }

  /// Replaces a card in place after it was edited elsewhere (e.g. returning
  /// from the post-detail / edit screen), so the feed shows the new data
  /// without a full refresh.
  void replaceLoad(Load updated) => _replace(updated);

  /// Removes a card after it was deleted elsewhere (e.g. from post detail).
  void removeLoad(int id) {
    final remaining = state.loads.where((l) => l.id != id).toList();
    emit(state.copyWith(
      loads: remaining,
      status: remaining.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
    ));
  }

  void _replace(Load updated) {
    emit(state.copyWith(
      loads: [
        for (final l in state.loads) if (l.id == updated.id) updated else l,
      ],
    ));
  }
}
