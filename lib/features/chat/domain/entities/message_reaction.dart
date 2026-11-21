import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

class ReactionUser extends Equatable {
  const ReactionUser({required this.id, required this.name});
  final int id;
  final String name;
  factory ReactionUser.fromJson(Map<String, dynamic> json) => ReactionUser(
    id: json.asIntOr('id', 0),
    name: json.asStringOr('name', 'User'),
  );
  @override
  List<Object?> get props => [id, name];
}

class MessageReaction extends Equatable {
  const MessageReaction({
    required this.emoji,
    required this.count,
    this.users = const [],
  });
  final String emoji;
  final int count;
  final List<ReactionUser> users;
  factory MessageReaction.fromJson(Map<String, dynamic> json) =>
      MessageReaction(
        emoji: json.asStringOr('emoji', ''),
        count: json.asIntOr('count', 0),
        users: [
          for (final user
              in json['users'] is List ? json['users'] as List : const [])
            if (user is Map<String, dynamic>) ReactionUser.fromJson(user),
        ],
      );
  static List<MessageReaction> parse(Object? raw) => [
    for (final item in raw is List ? raw : const [])
      if (item is Map<String, dynamic>) MessageReaction.fromJson(item),
  ];
  @override
  List<Object?> get props => [emoji, count, users];
}

class ReactionUpdate {
  const ReactionUpdate({
    required this.messageId,
    required this.reactions,
    this.myReaction,
  });
  final int messageId;
  final String? myReaction;
  final List<MessageReaction> reactions;
  factory ReactionUpdate.fromJson(Map<String, dynamic> json, {int? meId}) {
    final reactions = MessageReaction.parse(json['reactions']);
    String? mine = json.asString('my_reaction');
    if (!json.containsKey('my_reaction') && meId != null) {
      for (final reaction in reactions) {
        if (reaction.users.any((u) => u.id == meId)) mine = reaction.emoji;
      }
    }
    return ReactionUpdate(
      messageId: json.asIntOr('message_id', 0),
      reactions: reactions,
      myReaction: mine,
    );
  }
}

enum MessageDeleteScope { me, everyone }
