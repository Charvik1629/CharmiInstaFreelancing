import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';
import '../../../../core/models/user.dart';

/// A pending request to join a group (`GET /groups/{id}/join-requests`).
class GroupJoinRequest extends Equatable {
  const GroupJoinRequest({
    required this.id,
    required this.status,
    this.note,
    this.user,
    this.createdAt,
  });

  final int id;
  final String status; // pending | approved | declined
  final String? note;
  final User? user;
  final DateTime? createdAt;

  factory GroupJoinRequest.fromJson(Map<String, dynamic> json) {
    final u = json.asMap('user');
    return GroupJoinRequest(
      id: json.asIntOr('id', 0),
      status: json.asStringOr('status', 'pending'),
      note: json.asString('note'),
      user: u == null ? null : User.fromJson(u),
      createdAt: json.asDate('created_at'),
    );
  }

  @override
  List<Object?> get props => [id, status, note, user, createdAt];
}
