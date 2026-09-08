import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/pin_settings.dart';
import '../../domain/security_repository.dart';

part 'security_state.dart';

/// Drives the chat-PIN security screen (GET/PUT /security/pin).
class SecurityCubit extends Cubit<SecurityState> {
  SecurityCubit(this._repository) : super(const SecurityState());

  final SecurityRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: SecurityStatus.loading));
    final result = await _repository.getPin();
    switch (result) {
      case Success(value: final pin):
        emit(state.copyWith(status: SecurityStatus.loaded, settings: pin));
      case Err(failure: final f):
        emit(state.copyWith(status: SecurityStatus.error, errorMessage: f.message));
    }
  }

  /// Saves the PIN mode (and 4-digit PIN when mode is `own`).
  Future<bool> save({required String mode, String? pin}) async {
    if (mode == 'own' && (pin == null || pin.length != 4)) {
      emit(state.copyWith(errorMessage: 'Enter a 4-digit PIN', saving: false));
      return false;
    }
    emit(state.copyWith(saving: true, clearError: true));
    final result = await _repository.setPin(mode: mode, pin: pin);
    switch (result) {
      case Success(value: final settings):
        emit(state.copyWith(saving: false, settings: settings, saved: true));
        return true;
      case Err(failure: final f):
        emit(state.copyWith(saving: false, errorMessage: f.message));
        return false;
    }
  }
}
