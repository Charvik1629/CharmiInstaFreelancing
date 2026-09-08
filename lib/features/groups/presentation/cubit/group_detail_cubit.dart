import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_join_request.dart';
import '../../domain/repositories/groups_repository.dart';

part 'group_detail_state.dart';

/// Loads a group's info + members, handles the viewer's join/cancel/leave, and —
/// for admins ([isManager]) — lists pending join requests with approve/decline
/// and member removal.
class GroupDetailCubit extends Cubit<GroupDetailState> {
  GroupDetailCubit(this._repository, this.groupId)
      : super(const GroupDetailState());

  final GroupsRepository _repository;
  final int groupId;

  Future<void> load({bool isManager = false}) async {
    emit(state.copyWith(status: DetailStatus.loading, isManager: isManager));
    final groupResult = await _repository.getGroup(groupId);
    if (groupResult case Err(failure: final f)) {
      emit(state.copyWith(status: DetailStatus.error, errorMessage: f.message));
      return;
    }
    final members = await _repository.getMembers(groupId);
    final requests = isManager
        ? await _repository.getJoinRequests(groupId)
        : const Success<List<GroupJoinRequest>>([]);
    emit(state.copyWith(
      status: DetailStatus.loaded,
      group: (groupResult as Success<Group>).value,
      members: members.valueOrNull ?? const [],
      joinRequests: requests.valueOrNull ?? const [],
    ));
  }

  Future<void> _reload() => load(isManager: state.isManager);

  Future<bool> requestJoin() async {
    final result = await _repository.requestJoin(groupId);
    if (result.isSuccess) {
      await _reload();
    } else {
      emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    }
    return result.isSuccess;
  }

  Future<bool> cancelRequest() async {
    final result = await _repository.cancelJoinRequest(groupId);
    if (result.isSuccess) {
      await _reload();
    } else {
      emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    }
    return result.isSuccess;
  }

  Future<bool> leave() async {
    final result = await _repository.leave(groupId);
    if (result.isSuccess) {
      await _reload();
    } else {
      emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    }
    return result.isSuccess;
  }

  Future<bool> approveRequest(GroupJoinRequest r) async {
    if (state.actingOnId != null) return false;
    emit(state.copyWith(actingOnId: r.id));
    final result = await _repository.approveJoinRequest(groupId, r.id);
    return _afterReview(result, r);
  }

  Future<bool> declineRequest(GroupJoinRequest r) async {
    if (state.actingOnId != null) return false;
    emit(state.copyWith(actingOnId: r.id));
    final result = await _repository.declineJoinRequest(groupId, r.id);
    return _afterReview(result, r);
  }

  Future<bool> _afterReview(Result<void> result, GroupJoinRequest r) async {
    if (result.isSuccess) {
      // Drop the row, then reload members/counts.
      emit(state.copyWith(
        joinRequests:
            state.joinRequests.where((x) => x.id != r.id).toList(),
        clearActingOn: true,
      ));
      await _reload();
      return true;
    }
    emit(state.copyWith(
        errorMessage: result.failureOrNull?.message, clearActingOn: true));
    return false;
  }

  Future<bool> removeMember(GroupMember m) async {
    final result = await _repository.removeMember(groupId, m.id);
    if (result.isSuccess) {
      emit(state.copyWith(
        members: state.members.where((x) => x.id != m.id).toList(),
      ));
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }
}
