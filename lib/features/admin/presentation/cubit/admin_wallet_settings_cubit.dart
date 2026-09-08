import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/wallet_settings.dart';
import '../../domain/repositories/admin_wallet_repository.dart';

part 'admin_wallet_settings_state.dart';

/// Loads and edits the wallet economy settings (post cost, boost cost & duration,
/// business boost, broadcast costs).
class AdminWalletSettingsCubit extends Cubit<AdminWalletSettingsState> {
  AdminWalletSettingsCubit(this._repository)
      : super(const AdminWalletSettingsState());

  final AdminWalletRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: SettingsStatus.loading));
    final result = await _repository.getSettings();
    switch (result) {
      case Success(value: final s):
        emit(state.copyWith(status: SettingsStatus.loaded, settings: s));
      case Err(failure: final f):
        emit(state.copyWith(
            status: SettingsStatus.error, errorMessage: f.message));
    }
  }

  /// Saves the given field changes (a subset of settings). Returns success.
  Future<bool> save(Map<String, dynamic> changes) async {
    emit(state.copyWith(saving: true));
    final result = await _repository.updateSettings(changes);
    switch (result) {
      case Success(value: final s):
        emit(state.copyWith(settings: s, saving: false));
        return true;
      case Err(failure: final f):
        emit(state.copyWith(saving: false, errorMessage: f.message));
        return false;
    }
  }
}
