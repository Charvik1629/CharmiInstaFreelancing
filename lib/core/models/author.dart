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
    this.isVerified = false,
  });

  final int id;
  final String name;
  final String? avatarUrl;
  final DateTime? lastSeenAt;
  final bool isVerified;

  factory Author.fromJson(Map<String, dynamic> json) => Author(
        id: json.asIntOr('id', 0),
        name: json.asStringOr('name', ''),
        avatarUrl: json.asString('avatar_url'),
        lastSeenAt: json.asDate('last_seen_at'),
        isVerified: json.asBool('is_verified'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar_url': avatarUrl,
        'last_seen_at': lastSeenAt?.toIso8601String(),
        'is_verified': isVerified,
      };

  @override
  List<Object?> get props => [id, name, avatarUrl, lastSeenAt, isVerified];
}
