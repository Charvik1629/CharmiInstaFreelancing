part of 'search_cubit.dart';

enum SearchStatus { idle, searching, results, empty, error }

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.results = const [],
    this.recents = const [],
    this.errorMessage,
  });

  final SearchStatus status;
  final String query;
  final List<User> results;
  final List<String> recents;
  final String? errorMessage;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<User>? results,
    List<String>? recents,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
      recents: recents ?? this.recents,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, query, results, recents, errorMessage];
}
