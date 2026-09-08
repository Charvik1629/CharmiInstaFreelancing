import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';

/// Domain contract for search. People search is live via GET /users?q=; content
/// (post) search has no text query in the API yet (see MISSING_APIS "Search").
abstract class SearchRepository {
  Future<Result<List<User>>> searchUsers(String query);
}
