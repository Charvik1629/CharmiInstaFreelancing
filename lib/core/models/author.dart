import 'package:equatable/equatable.dart';

import '../extensions/json_extensions.dart';

/// A lightweight reference to a user as it appears embedded in other resources
/// (a load's author, a conversation peer). Distinct from the full [User].
class Author extends Equatable {
  const Author({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.lastSeenAt,
  });

  final int id;
  final String name;
  final String? avatarUrl;
  final DateTime? lastSeenAt;

  factory Author.fromJson(Map<String, dynamic> json) => Author(
        id: json.asIntOr('id', 0),
        name: json.asStringOr('name', ''),
        avatarUrl: json.asString('avatar_url'),
        lastSeenAt: json.asDate('last_seen_at'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar_url': avatarUrl,
        'last_seen_at': lastSeenAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, name, avatarUrl, lastSeenAt];
}
