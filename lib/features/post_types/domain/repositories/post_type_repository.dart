import '../../../../core/models/post_type.dart';
import '../../../../core/utils/result.dart';

/// Domain contract for post types. Presentation depends on this, not on the
/// datasource, so the data source can change without touching the UI.
abstract class PostTypeRepository {
  Future<Result<List<PostType>>> getPostTypes();
}
