import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';
import '../../../search/domain/repositories/search_repository.dart';
import '../../domain/broadcast_detail.dart';
import '../../domain/broadcasts_repository.dart';

part 'create_broadcast_state.dart';

/// Drives "New broadcast": name the list, search + pick recipients, create.
class CreateBroadcastCubit extends Cubit<CreateBroadcastState> {
  CreateBroadcastCubit(this._broadcasts, this._search)
      : super(const CreateBroadcastState());

  final BroadcastsRepository _broadcasts;
  final SearchRepository _search;

  void setName(String v) => emit(state.copyWith(name: v, clearError: true));

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      emit(state.copyWith(results: const [], searching: false));
      return;
    }
    emit(state.copyWith(searching: true));
    final result = await _search.searchUsers(q);
    emit(state.copyWith(searching: false, results: result.valueOrNull ?? const []));
  }

  void toggle(User user) {
    final selected = [...state.selected];
    final idx = selected.indexWhere((u) => u.id == user.id);
    if (idx >= 0) {
      selected.removeAt(idx);
    } else {
      selected.add(user);
    }
    emit(state.copyWith(selected: selected));
  }

  bool isSelected(User user) => state.selected.any((u) => u.id == user.id);

  Future<void> submit() async {
    if (state.isSubmitting || !state.canSubmit) return;
    emit(state.copyWith(status: CreateStatus.submitting, clearError: true));
    final result = await _broadcasts.create(
      name: state.name.trim(),
      userIds: state.selected.map((u) => u.id).toList(),
    );
    switch (result) {
      case Success(value: final detail):
        emit(state.copyWith(status: CreateStatus.success, created: detail));
      case Err(failure: final f):
        emit(state.copyWith(status: CreateStatus.failure, errorMessage: f.message));
    }
  }
}
