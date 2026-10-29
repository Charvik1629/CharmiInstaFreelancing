part of 'chat_list_cubit.dart';

enum ChatListStatus { initial, loading, loaded, empty, error }

/// Inbox filter tabs. [all] merges direct + group + broadcast; [unread] keeps
/// only conversations with an unread count.
enum ChatFilter {
  all('All'),
  unread('Unread'),
  direct('Direct'),
  groups('Groups'),
  questions('Questions'),
  photos('Photos'),
  videos('Videos'),
  voice('Voice'),
  links('Links'),
  broadcasts('Broadcasts');

  const ChatFilter(this.label);
  final String label;
}

class ChatListState extends Equatable {
  const ChatListState({
    this.status = ChatListStatus.initial,
    this.conversations = const [],
    this.filter = ChatFilter.all,
    this.labels = const [],
    this.labelFilterId,
    this.errorMessage,
    this.people = const [],
    this.query = '',
  });

  final ChatListStatus status;
  final List<Conversation> conversations;
  final ChatFilter filter;

  /// Current inbox search text (so the search field can be reset externally).
  final String query;

  /// The user's labels (for the filter row + attach sheet).
  final List<ChatLabel> labels;

  /// When set, the list shows only conversations carrying this label.
  final int? labelFilterId;

  final String? errorMessage;

  /// People matching the search term (GET /users?q=) — shown while searching so
  /// a new chat can be started from the inbox. Empty when not searching.
  final List<User> people;

  ChatListState copyWith({
    ChatListStatus? status,
    List<Conversation>? conversations,
    ChatFilter? filter,
    List<ChatLabel>? labels,
    int? labelFilterId,
    bool clearLabelFilter = false,
    String? errorMessage,
    bool clearError = false,
    List<User>? people,
    String? query,
  }) {
    return ChatListState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      filter: filter ?? this.filter,
      labels: labels ?? this.labels,
      labelFilterId:
          clearLabelFilter ? null : (labelFilterId ?? this.labelFilterId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      people: people ?? this.people,
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props =>
      [status, conversations, filter, labels, labelFilterId, errorMessage, people, query];
}
