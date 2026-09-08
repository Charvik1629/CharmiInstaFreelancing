part of 'security_cubit.dart';

enum SecurityStatus { initial, loading, loaded, error }

class SecurityState extends Equatable {
  const SecurityState({
    this.status = SecurityStatus.initial,
    this.settings = const PinSettings(),
    this.saving = false,
    this.saved = false,
    this.errorMessage,
  });

  final SecurityStatus status;
  final PinSettings settings;
  final bool saving;
  final bool saved;
  final String? errorMessage;

  SecurityState copyWith({
    SecurityStatus? status,
    PinSettings? settings,
    bool? saving,
    bool? saved,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SecurityState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      saving: saving ?? this.saving,
      saved: saved ?? this.saved,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, settings, saving, saved, errorMessage];
}
