import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// The viewer's relationship to a group.
enum GroupViewerStatus { none, pending, member }

GroupViewerStatus _statusFrom(String? raw) => switch (raw) {
      'member' => GroupViewerStatus.member,
      'pending' => GroupViewerStatus.pending,
      _ => GroupViewerStatus.none,
    };

/// A group (GET /groups, /groups/recommended, /groups/{id}).
class Group extends Equatable {
  const Group({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    this.viewerStatus = GroupViewerStatus.none,
    this.canChat = false,
    this.conversationId,
    this.isPrivate = true,
    this.memberCount,
    this.creatorName,
    this.pendingJoinRequestCount = 0,
  });

  final int id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final GroupViewerStatus viewerStatus;
  final bool canChat;
  final int? conversationId;
  final bool isPrivate;
  final int? memberCount;
  final String? creatorName;
  final int pendingJoinRequestCount;

  bool get isMember => viewerStatus == GroupViewerStatus.member;
  bool get isPending => viewerStatus == GroupViewerStatus.pending;

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json.asIntOr('id', 0),
        name: json.asStringOr('name', ''),
        description: json.asString('description'),
        avatarUrl: json.asString('avatar_url'),
        viewerStatus: _statusFrom(json.asString('viewer_status')),
        canChat: json.asBool('can_chat'),
        conversationId: json.asInt('conversation_id'),
        isPrivate: json.asBool('is_private', fallback: true),
        memberCount: json.asInt('member_count'),
        creatorName: json.asMap('creator')?.asString('name'),
        pendingJoinRequestCount: json.asIntOr('pending_join_request_count', 0),
      );

  @override
  List<Object?> get props =>
      [id, name, description, avatarUrl, viewerStatus, canChat, conversationId, memberCount];
}

/// A group member (GET /groups/{id}/members).
class GroupMember extends Equatable {
  const GroupMember({required this.id, required this.name, this.avatarUrl, this.role});

  final int id;
  final String name;
  final String? avatarUrl;
  final String? role;

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        id: json.asIntOr('id', 0),
        name: json.asStringOr('name', ''),
        avatarUrl: json.asString('avatar_url'),
        role: json.asString('role'),
      );

  @override
  List<Object?> get props => [id, name, avatarUrl, role];
}
