import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';
import 'chat_message.dart';

class DisappearingDuration extends Equatable {
  const DisappearingDuration(this.hours, this.label);
  final int hours;
  final String label;
  factory DisappearingDuration.fromJson(Map<String, dynamic> json) =>
      DisappearingDuration(
        json.asIntOr('hours', 0),
        json.asStringOr('label', '${json['hours']} hours'),
      );
  @override
  List<Object?> get props => [hours, label];
}

class DisappearingSettings extends Equatable {
  const DisappearingSettings({this.enabled = false, this.hours, this.label});
  final bool enabled;
  final int? hours;
  final String? label;
  String get displayLabel => !enabled ? 'Off' : label ?? '$hours hours';
  factory DisappearingSettings.fromJson(Map<String, dynamic> json) =>
      DisappearingSettings(
        enabled: json.asBool('disappearing_messages'),
        hours: json.asInt('disappearing_duration_hours'),
        label: json.asString('disappearing_duration_label'),
      );
  @override
  List<Object?> get props => [enabled, hours, label];
}

class DisappearingUpdate {
  const DisappearingUpdate(this.settings, this.message);
  final DisappearingSettings settings;
  final ChatMessage? message;
  factory DisappearingUpdate.fromJson(Map<String, dynamic> json) =>
      DisappearingUpdate(
        DisappearingSettings.fromJson(json.asMap('conversation') ?? json),
        json.asMap('message') == null
            ? null
            : ChatMessage.fromJson(json.asMap('message')!),
      );
}
