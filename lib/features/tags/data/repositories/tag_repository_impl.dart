import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/tag.dart';
import '../../domain/repositories/tag_repository.dart';
import '../datasources/tag_remote_data_source.dart';

class TagRepositoryImpl with BaseRepository implements TagRepository {
  TagRepositoryImpl(this._remote);

  final TagRemoteDataSource _remote;

  @override
  Future<Result<List<Tag>>> getTags() => guard(_remote.getTags);

  @override
  Future<Result<List<Tag>>> getAllTags() => guard(_remote.getAllTags);

  @override
  Future<Result<Tag>> createTag({
    required String name,
    String? slug,
    required bool isActive,
    required int sortOrder,
  }) =>
      guard(() => _remote.createTag(
            name: name,
            slug: slug,
            isActive: isActive,
            sortOrder: sortOrder,
          ));

  @override
  Future<Result<Tag>> updateTag({
    required int id,
    required String name,
    String? slug,
    required bool isActive,
    required int sortOrder,
  }) =>
      guard(() => _remote.updateTag(
            id: id,
            name: name,
            slug: slug,
            isActive: isActive,
            sortOrder: sortOrder,
          ));

  @override
  Future<Result<void>> deleteTag(int id) => guard(() => _remote.deleteTag(id));
}
