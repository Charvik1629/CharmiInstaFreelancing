import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/tags/domain/entities/tag.dart';
import 'package:charmi_insta_freelancing/features/tags/domain/repositories/tag_repository.dart';
import 'package:charmi_insta_freelancing/features/tags/presentation/cubit/admin_tags_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TagRepository {}

const _urgent = Tag(id: 1, name: 'Urgent', slug: 'urgent', sortOrder: 1);
const _local = Tag(id: 2, name: 'Local', slug: 'local', sortOrder: 2);

void main() {
  late _MockRepo repo;
  setUp(() => repo = _MockRepo());

  group('Tag.fromJson', () {
    test('parses fields with is_active default true', () {
      final t = Tag.fromJson(const {
        'id': 3,
        'name': 'Container',
        'slug': 'container',
        'sort_order': 4,
      });
      expect(t.id, 3);
      expect(t.name, 'Container');
      expect(t.isActive, isTrue);
      expect(t.sortOrder, 4);
    });
  });

  group('AdminTagsCubit', () {
    test('load emits loaded, sorted by sort order', () async {
      when(repo.getAllTags)
          .thenAnswer((_) async => const Success([_local, _urgent]));
      final cubit = AdminTagsCubit(repo);
      await cubit.load();
      expect(cubit.state.status, TagsStatus.loaded);
      expect(cubit.state.tags.map((t) => t.id), [1, 2]);
    });

    test('load emits empty when there are no tags', () async {
      when(repo.getAllTags).thenAnswer((_) async => const Success([]));
      final cubit = AdminTagsCubit(repo);
      await cubit.load();
      expect(cubit.state.status, TagsStatus.empty);
    });

    test('createTag appends and re-sorts', () async {
      when(repo.getAllTags).thenAnswer((_) async => const Success([_urgent]));
      when(() => repo.createTag(
            name: any(named: 'name'),
            slug: any(named: 'slug'),
            isActive: any(named: 'isActive'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer((_) async => const Success(_local));
      final cubit = AdminTagsCubit(repo);
      await cubit.load();
      final ok =
          await cubit.createTag(name: 'Local', isActive: true, sortOrder: 2);
      expect(ok, isTrue);
      expect(cubit.state.tags.map((t) => t.id), [1, 2]);
    });

    test('updateTag replaces the row', () async {
      when(repo.getAllTags)
          .thenAnswer((_) async => const Success([_urgent, _local]));
      when(() => repo.updateTag(
            id: 1,
            name: any(named: 'name'),
            slug: any(named: 'slug'),
            isActive: any(named: 'isActive'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer((_) async => const Success(
          Tag(id: 1, name: 'Urgent', slug: 'urgent', isActive: false, sortOrder: 1)));
      final cubit = AdminTagsCubit(repo);
      await cubit.load();
      final ok = await cubit.updateTag(
          id: 1, name: 'Urgent', isActive: false, sortOrder: 1);
      expect(ok, isTrue);
      expect(cubit.state.tags.firstWhere((t) => t.id == 1).isActive, isFalse);
    });

    test('deleteTag removes the row', () async {
      when(repo.getAllTags)
          .thenAnswer((_) async => const Success([_urgent, _local]));
      when(() => repo.deleteTag(2))
          .thenAnswer((_) async => const Success(null));
      final cubit = AdminTagsCubit(repo);
      await cubit.load();
      final ok = await cubit.deleteTag(2);
      expect(ok, isTrue);
      expect(cubit.state.tags.map((t) => t.id), [1]);
    });

    test('createTag failure surfaces the message', () async {
      when(repo.getAllTags).thenAnswer((_) async => const Success([]));
      when(() => repo.createTag(
            name: any(named: 'name'),
            slug: any(named: 'slug'),
            isActive: any(named: 'isActive'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer(
          (_) async => const Err(ValidationFailure('duplicate slug')));
      final cubit = AdminTagsCubit(repo);
      await cubit.load();
      final ok =
          await cubit.createTag(name: 'Urgent', isActive: true, sortOrder: 0);
      expect(ok, isFalse);
      expect(cubit.state.errorMessage, 'duplicate slug');
    });
  });
}
