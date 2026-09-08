import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/group.dart';
import '../../domain/repositories/groups_repository.dart';

part 'groups_list_state.dart';

/// Loads the Groups screen: the user's groups + a recommended list, and handles
/// join requests.
class GroupsListCubit extends Cubit<GroupsListState> {
  GroupsListCubit(this._repository) : super(const GroupsListState());

  final GroupsRepository _repository;

  Future<void> load({bool isManager = false}) async {
    emit(state.copyWith(status: GroupsStatus.loading));
    final mine = await _repository.getMyGroups();
    final recommended = await _repository.getRecommended();
    if (mine is Err && recommended is Err) {
      emit(state.copyWith(
          status: GroupsStatus.error,
          errorMessage: mine.failureOrNull?.message ?? 'Could not load groups'));
      return;
    }
    // Admin-only pending join-request headline (best effort).
    final total = isManager
        ? (await _repository.getJoinRequestSummaryTotal()).valueOrNull ?? 0
        : 0;
    emit(state.copyWith(
      status: GroupsStatus.loaded,
      myGroups: mine.valueOrNull ?? const [],
      recommended: recommended.valueOrNull ?? const [],
      pendingJoinTotal: total,
    ));
  }

  Future<void> refresh({bool isManager = false}) => load(isManager: isManager);

  Future<bool> join(Group group) async {
    final result = await _repository.requestJoin(group.id);
    if (result.isSuccess) await load();
    return result.isSuccess;
  }
}
