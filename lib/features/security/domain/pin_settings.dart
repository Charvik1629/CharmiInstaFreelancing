import 'package:equatable/equatable.dart';

import '../../../core/extensions/json_extensions.dart';

/// Chat PIN configuration (GET/PUT /security/pin). `own` = the user sets a fixed
/// 4-digit PIN; `random` = the app issues a fresh PIN each chat.
class PinSettings extends Equatable {
  const PinSettings({
    this.mode = 'random',
    this.configured = false,
    this.hasOwnPin = false,
    this.refreshesOnEachChat = false,
  });

  final String mode;
  final bool configured;
  final bool hasOwnPin;
  final bool refreshesOnEachChat;

  bool get isOwn => mode == 'own';

  factory PinSettings.fromJson(Map<String, dynamic> json) => PinSettings(
        mode: json.asStringOr('mode', 'random'),
        configured: json.asBool('configured'),
        hasOwnPin: json.asBool('has_own_pin'),
        refreshesOnEachChat: json.asBool('refreshes_on_each_chat'),
      );

  @override
  List<Object?> get props => [mode, configured, hasOwnPin, refreshesOnEachChat];
}
