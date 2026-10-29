import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';
import '../../../search/domain/repositories/search_repository.dart';
import '../../domain/entities/group.dart';
import '../../domain/repositories/groups_repository.dart';

part 'create_group_state.dart';

/// Drives "New group": name it, search + pick members, create.
class CreateGroupCubit extends Cubit<CreateGroupState> {
  CreateGroupCubit(this._groups, this._search)
      : super(const CreateGroupState());

  final GroupsRepository _groups;
  final SearchRepository _search;

  void setName(String v) => emit(state.copyWith(name: v, clearError: true));

  void setDescription(String v) =>
      emit(state.copyWith(description: v, clearError: true));

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      emit(state.copyWith(results: const [], searching: false));
      return;
    }
    emit(state.copyWith(searching: true));
    final result = await _search.searchUsers(q);
    if (isClosed) return;
    emit(state.copyWith(
        searching: false, results: result.valueOrNull ?? const []));
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
    final result = await _groups.createGroup(
      name: state.name.trim(),
      description:
          state.description.trim().isEmpty ? null : state.description.trim(),
      userIds: state.selected.map((u) => u.id).toList(),
    );
    if (isClosed) return;
    switch (result) {
      case Success(value: final group):
        emit(state.copyWith(status: CreateStatus.success, created: group));
      case Err(failure: final f):
        emit(state.copyWith(
            status: CreateStatus.failure, errorMessage: f.message));
    }
  }
}
