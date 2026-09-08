import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// Unread badge totals from `GET /chats/unread-count`.
class UnreadCounts extends Equatable {
  const UnreadCounts({
    this.total = 0,
    this.chats = 0,
    this.questions = 0,
    this.offers = 0,
  });

  final int total;
  final int chats;
  final int questions;
  final int offers;

  /// Badge for the Chat tab: direct/group + Q&A (offers have their own screen).
  int get inbox => chats + questions;

  factory UnreadCounts.fromJson(Map<String, dynamic> json) => UnreadCounts(
        total: json.asIntOr('total', 0),
        chats: json.asIntOr('chats', 0),
        questions: json.asIntOr('questions', 0),
        offers: json.asIntOr('offers', 0),
      );

  @override
  List<Object?> get props => [total, chats, questions, offers];
}
