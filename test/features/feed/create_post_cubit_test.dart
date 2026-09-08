import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/models/load.dart';
import 'package:charmi_insta_freelancing/core/models/post_type.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/feed/domain/entities/new_post.dart';
import 'package:charmi_insta_freelancing/features/feed/domain/repositories/feed_repository.dart';
import 'package:charmi_insta_freelancing/features/feed/presentation/cubit/create_post_cubit.dart';
import 'package:charmi_insta_freelancing/features/post_types/domain/repositories/post_type_repository.dart';
import 'package:charmi_insta_freelancing/features/tags/domain/entities/tag.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFeedRepo extends Mock implements FeedRepository {}

class _MockPostTypeRepo extends Mock implements PostTypeRepository {}

PostType _type(int id, String slug, {bool active = true}) =>
    PostType(id: id, slug: slug, name: slug, isActive: active);

Load _load(int id) => Load(id: id, title: 'Post $id');

void main() {
  late _MockFeedRepo feed;
  late _MockPostTypeRepo postTypes;

  setUpAll(() => registerFallbackValue(const NewPost(title: 'x')));
  setUp(() {
    feed = _MockFeedRepo();
    postTypes = _MockPostTypeRepo();
  });

  CreatePostCubit build() => CreatePostCubit(feed, postTypes);

  group('loadCategories', () {
    test('keeps only active types and defaults selection to the first', () async {
      when(() => postTypes.getPostTypes()).thenAnswer(
        (_) async => Success([_type(1, 'buy'), _type(2, 'sell', active: false), _type(3, 'business')]),
      );
      final cubit = build();
      await cubit.loadCategories();

      expect(cubit.state.categoriesStatus, LoadStatus.loaded);
      expect(cubit.state.categories.map((t) => t.id), [1, 3]);
      expect(cubit.state.selectedTypeId, 1);
    });

    test('failure sets error status, leaves categories empty', () async {
      when(() => postTypes.getPostTypes())
          .thenAnswer((_) async => const Err(NetworkFailure('offline')));
      final cubit = build();
      await cubit.loadCategories();

      expect(cubit.state.categoriesStatus, LoadStatus.error);
      expect(cubit.state.categories, isEmpty);
    });
  });

  group('form validation', () {
    test('canSubmit is false until the title has content', () {
      final cubit = build();
      expect(cubit.state.canSubmit, isFalse);
      cubit.setTitle('   ');
      expect(cubit.state.canSubmit, isFalse);
      cubit.setTitle('Selling a bike');
      expect(cubit.state.canSubmit, isTrue);
    });

    test('submit is a no-op when the form is invalid', () async {
      final cubit = build();
      await cubit.submit();
      verifyNever(() => feed.createLoad(any()));
      expect(cubit.state.submitStatus, SubmitStatus.idle);
    });
  });

  group('images', () {
    test('add / remove toggle the strip', () {
      final cubit = build();
      cubit.addImage('/tmp/a.jpg');
      expect(cubit.state.hasImage, isTrue);
      cubit.removeImageAt(0);
      expect(cubit.state.hasImage, isFalse);
      expect(cubit.state.coverImagePath, isNull);
    });

    test('cover is the first image; extras are flagged', () {
      final cubit = build();
      cubit.addImage('/tmp/a.jpg');
      cubit.addImage('/tmp/b.jpg');
      expect(cubit.state.coverImagePath, '/tmp/a.jpg');
      expect(cubit.state.hasExtraImages, isTrue);
    });

    test('reorder moves the cover', () {
      final cubit = build();
      cubit.addImage('/tmp/a.jpg');
      cubit.addImage('/tmp/b.jpg');
      cubit.reorderImages(1, 0); // move b before a
      expect(cubit.state.imagePaths, ['/tmp/b.jpg', '/tmp/a.jpg']);
      expect(cubit.state.coverImagePath, '/tmp/b.jpg');
    });
  });

  group('submit', () {
    test('success emits created load and forwards trimmed fields', () async {
      when(() => feed.createLoad(any()))
          .thenAnswer((_) async => Success(_load(42)));
      final cubit = build();
      cubit.setTitle('  Fresh mangoes  ');
      cubit.setBody('  ripe and sweet  ');
      cubit.selectType(7);

      await cubit.submit();

      expect(cubit.state.submitStatus, SubmitStatus.success);
      expect(cubit.state.created?.id, 42);

      final captured = verify(() => feed.createLoad(captureAny())).captured.single as NewPost;
      expect(captured.title, 'Fresh mangoes');
      expect(captured.body, 'ripe and sweet');
      expect(captured.postTypeId, 7);
    });

    test('selected tags are forwarded as tag ids', () async {
      when(() => feed.createLoad(any()))
          .thenAnswer((_) async => Success(_load(9)));
      final cubit = build();
      cubit.setTitle('Container load');
      cubit.setTags(const [
        Tag(id: 4, name: 'Container'),
        Tag(id: 1, name: 'Urgent'),
      ]);

      await cubit.submit();

      final captured =
          verify(() => feed.createLoad(captureAny())).captured.single as NewPost;
      expect(captured.tagIds, [4, 1]);
    });

    test('empty body is sent as null', () async {
      when(() => feed.createLoad(any()))
          .thenAnswer((_) async => Success(_load(1)));
      final cubit = build();
      cubit.setTitle('Title only');
      await cubit.submit();

      final captured = verify(() => feed.createLoad(captureAny())).captured.single as NewPost;
      expect(captured.body, isNull);
    });

    test('generic failure surfaces the error message', () async {
      when(() => feed.createLoad(any()))
          .thenAnswer((_) async => const Err(ServerFailure('boom')));
      final cubit = build();
      cubit.setTitle('Title');
      await cubit.submit();

      expect(cubit.state.submitStatus, SubmitStatus.failure);
      expect(cubit.state.errorMessage, 'boom');
      expect(cubit.state.created, isNull);
    });

    test('422 validation failure flattens field errors to first message', () async {
      when(() => feed.createLoad(any())).thenAnswer(
        (_) async => const Err(ValidationFailure('Invalid', fieldErrors: {
          'title': ['Title is required', 'and too short'],
          'body': ['Body invalid'],
        })),
      );
      final cubit = build();
      cubit.setTitle('x');
      await cubit.submit();

      expect(cubit.state.submitStatus, SubmitStatus.failure);
      expect(cubit.state.fieldErrors['title'], 'Title is required');
      expect(cubit.state.fieldErrors['body'], 'Body invalid');
    });

    test('does not double-submit while a submit is in flight', () async {
      var calls = 0;
      when(() => feed.createLoad(any())).thenAnswer((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return Success(_load(1));
      });
      final cubit = build();
      cubit.setTitle('Title');

      await Future.wait([cubit.submit(), cubit.submit()]);
      expect(calls, 1);
    });
  });
}
