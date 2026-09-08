import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/profile_update.dart';
import '../../domain/repositories/profile_repository.dart';

part 'edit_profile_state.dart';

/// Drives the Edit Profile form. Seeded from the current [User]; submits only
/// the fields that actually changed so an untouched form is a no-op.
class EditProfileCubit extends Cubit<EditProfileState> {
  EditProfileCubit(this._repository, User current)
      : _current = current,
        super(EditProfileState(
          name: current.name,
          bio: current.bio ?? '',
          phone: current.phone ?? '',
        ));

  final ProfileRepository _repository;
  final User _current;

  void setName(String v) => emit(state.copyWith(name: v, clearError: true));
  void setBio(String v) => emit(state.copyWith(bio: v));
  void setPhone(String v) => emit(state.copyWith(phone: v));
  void setAvatar(String path) => emit(state.copyWith(avatarPath: path));

  Future<void> submit() async {
    if (state.isSubmitting || !state.canSubmit) return;

    // Diff against the seeded user so we PUT only what changed.
    final name = state.name.trim();
    final bio = state.bio.trim();
    final phone = state.phone.trim();
    final update = ProfileUpdate(
      name: name != _current.name ? name : null,
      bio: bio != (_current.bio ?? '') ? bio : null,
      phone: phone != (_current.phone ?? '') ? phone : null,
      avatarPath: state.avatarPath,
    );

    if (update.isEmpty) {
      // Nothing changed — treat as an immediate success with the current user.
      emit(state.copyWith(status: EditStatus.success, saved: _current));
      return;
    }

    emit(state.copyWith(status: EditStatus.submitting, clearError: true));
    final result = await _repository.updateProfile(update);
    switch (result) {
      case Success(value: final user):
        emit(state.copyWith(status: EditStatus.success, saved: user));
      case Err(failure: final f):
        emit(state.copyWith(
          status: EditStatus.failure,
          errorMessage: f.message,
          fieldErrors: _flatten(f),
        ));
    }
  }

  static Map<String, String> _flatten(Failure f) {
    final raw = f is ValidationFailure ? f.fieldErrors : null;
    if (raw == null) return const {};
    return {
      for (final e in raw.entries)
        if (e.value.isNotEmpty) e.key: e.value.first,
    };
  }
}
