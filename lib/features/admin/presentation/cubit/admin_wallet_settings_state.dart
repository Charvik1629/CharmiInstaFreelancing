part of 'admin_wallet_settings_cubit.dart';

enum SettingsStatus { initial, loading, loaded, error }

class AdminWalletSettingsState extends Equatable {
  const AdminWalletSettingsState({
    this.status = SettingsStatus.initial,
    this.settings,
    this.saving = false,
    this.errorMessage,
  });

  final SettingsStatus status;
  final WalletSettings? settings;
  final bool saving;
  final String? errorMessage;

  AdminWalletSettingsState copyWith({
    SettingsStatus? status,
    WalletSettings? settings,
    bool? saving,
    String? errorMessage,
  }) {
    return AdminWalletSettingsState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      saving: saving ?? this.saving,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, settings, saving, errorMessage];
}
