import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/models/load.dart';
import 'package:charmi_insta_freelancing/core/network/api_response.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/feed/domain/repositories/feed_repository.dart';
import 'package:charmi_insta_freelancing/features/feed/presentation/cubit/feed_cubit.dart';

class _MockFeedRepo extends Mock implements FeedRepository {}

Load _load(int id, {bool own = false, bool requested = false}) => Load(
      id: id,
      title: 'Post $id',
      canMessage: !own,
      isOwn: own,
      viewerHasRequested: requested,
    );

PaginatedResponse<Load> _page(List<Load> items, {bool more = true}) =>
    PaginatedResponse(
      items: items,
      meta: PaginationMeta(currentPage: 1, lastPage: more ? 5 : 1),
    );

void main() {
  late _MockFeedRepo repo;
  setUp(() => repo = _MockFeedRepo());

  test('load populates items and hasMore', () async {
    when(() => repo.getLoads(page: 1, postTypeSlug: null))
        .thenAnswer((_) async => Success(_page([_load(1), _load(2)])));
    final cubit = FeedCubit(repo);
    await cubit.load();
    expect(cubit.state.status, FeedStatus.loaded);
    expect(cubit.state.loads.length, 2);
    expect(cubit.state.hasMore, isTrue);
  });

  test('load with empty result → empty status', () async {
    when(() => repo.getLoads(page: 1, postTypeSlug: null))
        .thenAnswer((_) async => Success(_page([], more: false)));
    final cubit = FeedCubit(repo);
    await cubit.load();
    expect(cubit.state.status, FeedStatus.empty);
  });

  test('load failure → error status with message', () async {
    when(() => repo.getLoads(page: 1, postTypeSlug: null))
        .thenAnswer((_) async => const Err(NetworkFailure()));
    final cubit = FeedCubit(repo);
    await cubit.load();
    expect(cubit.state.status, FeedStatus.error);
    expect(cubit.state.errorMessage, isNotNull);
  });

  test('loadMore appends next page and advances page', () async {
    when(() => repo.getLoads(page: 1, postTypeSlug: null))
        .thenAnswer((_) async => Success(_page([_load(1)])));
    when(() => repo.getLoads(page: 2, postTypeSlug: null))
        .thenAnswer((_) async => Success(_page([_load(2)], more: false)));
    final cubit = FeedCubit(repo);
    await cubit.load();
    await cubit.loadMore();
    expect(cubit.state.loads.map((l) => l.id), [1, 2]);
    expect(cubit.state.page, 2);
    expect(cubit.state.hasMore, isFalse);
  });

  test('loadMore no-ops when hasMore is false', () async {
    when(() => repo.getLoads(page: 1, postTypeSlug: null))
        .thenAnswer((_) async => Success(_page([_load(1)], more: false)));
    final cubit = FeedCubit(repo);
    await cubit.load();
    await cubit.loadMore();
    verifyNever(() => repo.getLoads(page: 2, postTypeSlug: any(named: 'postTypeSlug')));
  });

  test('setFilter reloads with the filter slug', () async {
    when(() => repo.getLoads(page: 1, postTypeSlug: null))
        .thenAnswer((_) async => Success(_page([_load(1)])));
    when(() => repo.getLoads(page: 1, postTypeSlug: 'buy'))
        .thenAnswer((_) async => Success(_page([_load(9)])));
    final cubit = FeedCubit(repo);
    await cubit.load();
    await cubit.setFilter(FeedFilter.buy);
    expect(cubit.state.filter, FeedFilter.buy);
    expect(cubit.state.loads.single.id, 9);
  });

  test('request flips the card to requested', () async {
    when(() => repo.getLoads(page: 1, postTypeSlug: null))
        .thenAnswer((_) async => Success(_page([_load(1)])));
    when(() => repo.requestLoad(1)).thenAnswer((_) async => const Success(7));
    final cubit = FeedCubit(repo);
    await cubit.load();
    final convId = await cubit.request(cubit.state.loads.first);
    expect(convId, 7);
    expect(cubit.state.loads.first.viewerHasRequested, isTrue);
  });

  test('delete removes the item; empty list → empty status', () async {
    when(() => repo.getLoads(page: 1, postTypeSlug: null))
        .thenAnswer((_) async => Success(_page([_load(1, own: true)], more: false)));
    when(() => repo.deleteLoad(1)).thenAnswer((_) async => const Success(null));
    final cubit = FeedCubit(repo);
    await cubit.load();
    await cubit.delete(cubit.state.loads.first);
    expect(cubit.state.loads, isEmpty);
    expect(cubit.state.status, FeedStatus.empty);
  });

  test('refresh keeps list on failure but sets errorMessage', () async {
    when(() => repo.getLoads(page: 1, postTypeSlug: null))
        .thenAnswer((_) async => Success(_page([_load(1)])));
    final cubit = FeedCubit(repo);
    await cubit.load();
    when(() => repo.getLoads(page: 1, postTypeSlug: null))
        .thenAnswer((_) async => const Err(NetworkFailure()));
    await cubit.refresh();
    expect(cubit.state.loads.length, 1);
    expect(cubit.state.errorMessage, isNotNull);
  });

  test('fixedSlug (Marketplace) always queries that post type', () async {
    when(() => repo.getLoads(page: 1, postTypeSlug: 'business'))
        .thenAnswer((_) async => Success(_page([_load(1)])));
    final cubit = FeedCubit(repo, fixedSlug: 'business');
    await cubit.load();
    expect(cubit.state.loads.length, 1);
    // Changing the filter must not override the fixed slug.
    await cubit.setFilter(FeedFilter.buy);
    verify(() => repo.getLoads(page: 1, postTypeSlug: 'business')).called(2);
    verifyNever(() => repo.getLoads(page: 1, postTypeSlug: 'buy'));
  });

  test('prepend inserts a new post at the top and flips empty→loaded', () async {
    when(() => repo.getLoads(page: 1, postTypeSlug: null))
        .thenAnswer((_) async => Success(_page([], more: false)));
    final cubit = FeedCubit(repo);
    await cubit.load();
    expect(cubit.state.status, FeedStatus.empty);

    cubit.prepend(_load(99));
    expect(cubit.state.status, FeedStatus.loaded);
    expect(cubit.state.loads.first.id, 99);

    cubit.prepend(_load(100));
    expect(cubit.state.loads.map((l) => l.id).toList(), [100, 99]);
  });

  group('boost', () {
    test('success flips the card to boosted in place', () async {
      when(() => repo.getLoads(page: 1, postTypeSlug: null))
          .thenAnswer((_) async => Success(_page([_load(1, own: true)])));
      when(() => repo.boostLoad(1))
          .thenAnswer((_) async => Success(_load(1, own: true)));
      final cubit = FeedCubit(repo);
      await cubit.load();

      final result = await cubit.boost(cubit.state.loads.first);
      expect(result.isSuccess, isTrue);
      expect(cubit.state.loads.first.isBoosted, isTrue);
      expect(cubit.state.loads.first.canBoost, isFalse);
    });

    test('402 insufficient credits leaves the card unchanged', () async {
      when(() => repo.getLoads(page: 1, postTypeSlug: null))
          .thenAnswer((_) async => Success(_page([_load(1, own: true)])));
      when(() => repo.boostLoad(1)).thenAnswer((_) async =>
          const Err(InsufficientCreditsFailure('Insufficient credits.')));
      final cubit = FeedCubit(repo);
      await cubit.load();

      final result = await cubit.boost(cubit.state.loads.first);
      expect(result.isFailure, isTrue);
      expect(cubit.state.loads.first.isBoosted, isFalse);
    });
  });
}
