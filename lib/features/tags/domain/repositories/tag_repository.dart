import '../../../../core/utils/result.dart';
import '../entities/tag.dart';

abstract class TagRepository {
  Future<Result<List<Tag>>> getTags();
  Future<Result<List<Tag>>> getAllTags();
  Future<Result<Tag>> createTag({
    required String name,
    String? slug,
    required bool isActive,
    required int sortOrder,
  });
  Future<Result<Tag>> updateTag({
    required int id,
    required String name,
    String? slug,
    required bool isActive,
    required int sortOrder,
  });
  Future<Result<void>> deleteTag(int id);
}
