import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../../broadcasts/domain/broadcast_detail.dart';
import '../../../broadcasts/domain/broadcasts_repository.dart';
import '../../../chat/domain/entities/broadcast_quota.dart';

part 'broadcast_groups_state.dart';

/// Drives the admin "Broadcast groups" listing: loads GET /broadcasts, supports
/// a (debounced) name search, and deletes a group.
class BroadcastGroupsCubit extends Cubit<BroadcastGroupsState> {
  BroadcastGroupsCubit(this._repository) : super(const BroadcastGroupsState());

  final BroadcastsRepository _repository;
  Timer? _debounce;

  Future<void> load() async {
    emit(state.copyWith(status: BroadcastGroupsStatus.loading));
    final result = await _repository.list(q: state.query.trim().isEmpty ? null : state.query.trim());
    switch (result) {
      case Success(value: final res):
        emit(state.copyWith(
          status: res.items.isEmpty
              ? BroadcastGroupsStatus.empty
              : BroadcastGroupsStatus.loaded,
          groups: res.items,
          quota: res.quota,
        ));
      case Err(failure: final f):
        emit(state.copyWith(
            status: BroadcastGroupsStatus.error, errorMessage: f.message));
    }
  }

  Future<void> refresh() => load();

  /// Debounced search: reloads the list from the server with the query.
  void search(String query) {
    emit(state.copyWith(query: query));
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), load);
  }

  /// Deletes a group and drops it from the list.
  Future<bool> delete(BroadcastDetail group) async {
    final result = await _repository.delete(group.id);
    if (result.isSuccess) {
      final remaining = state.groups.where((g) => g.id != group.id).toList();
      emit(state.copyWith(
        groups: remaining,
        status: remaining.isEmpty
            ? BroadcastGroupsStatus.empty
            : BroadcastGroupsStatus.loaded,
      ));
      return true;
    }
    return false;
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
