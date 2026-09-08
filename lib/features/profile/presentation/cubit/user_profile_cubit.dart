import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/profile_repository.dart';

part 'user_profile_state.dart';

/// Loads another user's public profile (GET /users/{id}).
class UserProfileCubit extends Cubit<UserProfileState> {
  UserProfileCubit(this._repository, this.userId)
      : super(const UserProfileState());

  final ProfileRepository _repository;
  final int userId;

  Future<void> load() async {
    emit(state.copyWith(status: UserProfileStatus.loading));
    final result = await _repository.getUser(userId);
    switch (result) {
      case Success(value: final user):
        emit(state.copyWith(status: UserProfileStatus.loaded, user: user));
      case Err(failure: final f):
        emit(state.copyWith(status: UserProfileStatus.error, errorMessage: f.message));
    }
  }
}
