import 'package:equatable/equatable.dart';

import '../../../core/extensions/json_extensions.dart';
import '../../../core/models/user.dart';

/// A broadcast group / list (GET /broadcasts, GET /broadcasts/{id},
/// POST /broadcasts). The live API names the group `title` and its size
/// `member_count`; older callers used `name`/`recipient_count`, so both spellings
/// are accepted when parsing.
class BroadcastDetail extends Equatable {
  const BroadcastDetail({
    required this.id,
    required this.name,
    this.description,
    this.memberCount = 0,
    this.avatarUrl,
    this.updatedAt,
    this.canDelete = false,
    this.recipients = const [],
  });

  final int id;
  final String name;
  final String? description;
  final int memberCount;
  final String? avatarUrl;
  final DateTime? updatedAt;
  final bool canDelete;
  final List<User> recipients;

  /// Legacy alias for [memberCount] kept for the user-facing broadcast detail UI.
  int get recipientCount => memberCount;

  factory BroadcastDetail.fromJson(Map<String, dynamic> json) {
    final raw = json['recipients'];
    final recipients = <User>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) recipients.add(User.fromJson(e));
      }
    }
    // The API uses `title`; tolerate the legacy `name` key too.
    final name = json.asString('title') ?? json.asStringOr('name', '');
    final memberCount = json.asInt('member_count') ??
        json.asIntOr('recipient_count', recipients.length);
    return BroadcastDetail(
      id: json.asIntOr('id', 0),
      name: name,
      description: json.asString('description'),
      memberCount: memberCount,
      avatarUrl: json.asString('avatar_url'),
      updatedAt: json.asDate('updated_at') ?? json.asDate('created_at'),
      canDelete: json.asBool('can_delete', fallback: true),
      recipients: recipients,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, description, memberCount, avatarUrl, updatedAt, canDelete, recipients];
}
