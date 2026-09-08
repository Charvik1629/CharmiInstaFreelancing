import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// One in-app notification (`GET /notifications`). [type] drives the icon:
/// `approval` · `offer` · `question` · `boost` · `credit` · `system`.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.read = false,
    this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String? body;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json.asIntOr('id', 0),
        type: json.asStringOr('type', 'system'),
        title: json.asStringOr('title', ''),
        body: json.asString('body') ?? json.asString('message'),
        read: json.asBool('read') || json.asBool('is_read'),
        createdAt: json.asDate('created_at'),
      );

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        read: read ?? this.read,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, type, title, body, read, createdAt];
}
