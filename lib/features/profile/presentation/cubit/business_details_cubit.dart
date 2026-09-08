import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/profile_update.dart';
import '../../domain/repositories/profile_repository.dart';

part 'business_details_state.dart';

/// Submits the "Fill Business Details" form. The page collects the fields (they
/// vary widely, so it owns the controllers) and hands a [ProfileUpdate] here.
class BusinessDetailsCubit extends Cubit<BusinessDetailsState> {
  BusinessDetailsCubit(this._repository)
      : super(const BusinessDetailsState());

  final ProfileRepository _repository;

  Future<void> submit(ProfileUpdate update) async {
    if (state.status == BdStatus.submitting) return;
    emit(state.copyWith(status: BdStatus.submitting, clearError: true));
    final result = await _repository.updateProfile(update);
    switch (result) {
      case Success(value: final user):
        emit(state.copyWith(status: BdStatus.success, saved: user));
      case Err(failure: final f):
        emit(state.copyWith(
          status: BdStatus.failure,
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
