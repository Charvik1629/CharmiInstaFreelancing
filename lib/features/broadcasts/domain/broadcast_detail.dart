import 'package:equatable/equatable.dart';

import '../../../core/extensions/json_extensions.dart';
import '../../../core/models/user.dart';

/// A broadcast list with its recipients (GET /broadcasts/{id}, POST /broadcasts).
class BroadcastDetail extends Equatable {
  const BroadcastDetail({
    required this.id,
    required this.name,
    this.recipientCount = 0,
    this.recipients = const [],
  });

  final int id;
  final String name;
  final int recipientCount;
  final List<User> recipients;

  factory BroadcastDetail.fromJson(Map<String, dynamic> json) {
    final raw = json['recipients'];
    final recipients = <User>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) recipients.add(User.fromJson(e));
      }
    }
    return BroadcastDetail(
      id: json.asIntOr('id', 0),
      name: json.asStringOr('name', ''),
      recipientCount: json.asIntOr('recipient_count', recipients.length),
      recipients: recipients,
    );
  }

  @override
  List<Object?> get props => [id, name, recipientCount, recipients];
}
