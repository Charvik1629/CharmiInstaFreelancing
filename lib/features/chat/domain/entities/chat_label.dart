import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/json_extensions.dart';

/// A personal, WhatsApp-style chat label (`GET /chat-labels`). [color] is a hex
/// string like `#25d366`.
class ChatLabel extends Equatable {
  const ChatLabel({
    required this.id,
    required this.name,
    this.color,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final String? color;
  final int sortOrder;

  /// The hex [color] parsed to a [Color], or a fallback when absent/invalid.
  Color colorValue(Color fallback) {
    final raw = (color ?? '').replaceAll('#', '').trim();
    if (raw.length == 6) {
      final v = int.tryParse('FF$raw', radix: 16);
      if (v != null) return Color(v);
    }
    return fallback;
  }

  factory ChatLabel.fromJson(Map<String, dynamic> json) => ChatLabel(
        id: json.asIntOr('id', 0),
        name: json.asStringOr('name', ''),
        color: json.asString('color'),
        sortOrder: json.asIntOr('sort_order', 0),
      );

  @override
  List<Object?> get props => [id, name, color, sortOrder];
}
