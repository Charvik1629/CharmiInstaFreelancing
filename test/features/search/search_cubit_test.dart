import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/models/user.dart';
import 'package:charmi_insta_freelancing/core/storage/storage_manager.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/search/domain/repositories/search_repository.dart';
import 'package:charmi_insta_freelancing/features/search/presentation/cubit/search_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSearchRepo extends Mock implements SearchRepository {}

class _MockStorage extends Mock implements StorageManager {}

User _user(int id, String name) => User(id: id, name: name);

void main() {
  late _MockSearchRepo repo;
  late _MockStorage storage;

  setUp(() {
    repo = _MockSearchRepo();
    storage = _MockStorage();
    // No recents cached by default; persistence is a no-op.
    when(() => storage.getString(any())).thenReturn(null);
    when(() => storage.setString(any(), any())).thenAnswer((_) async => true);
  });

  SearchCubit build() => SearchCubit(repo, storage);

  test('short query drops to idle and does not hit the API', () async {
    final cubit = build();
    cubit.onQueryChanged('a');
    expect(cubit.state.status, SearchStatus.idle);
    verifyNever(() => repo.searchUsers(any()));
  });

  test('runRecent with results populates and remembers the query', () async {
    when(() => repo.searchUsers('bob'))
        .thenAnswer((_) async => Success([_user(1, 'Bob'), _user(2, 'Bobby')]));
    final cubit = build();
    await cubit.runRecent('bob');

    expect(cubit.state.status, SearchStatus.results);
    expect(cubit.state.results.length, 2);
    expect(cubit.state.recents.first, 'bob');
    verify(() => storage.setString(any(), any())).called(1);
  });

  test('empty results → empty status', () async {
    when(() => repo.searchUsers('zzz')).thenAnswer((_) async => const Success([]));
    final cubit = build();
    await cubit.runRecent('zzz');
    expect(cubit.state.status, SearchStatus.empty);
  });

  test('failure → error status with message', () async {
    when(() => repo.searchUsers('bob'))
        .thenAnswer((_) async => const Err(NetworkFailure('offline')));
    final cubit = build();
    await cubit.runRecent('bob');
    expect(cubit.state.status, SearchStatus.error);
    expect(cubit.state.errorMessage, 'offline');
  });

  test('recents dedupe (case-insensitive) and cap at 8', () async {
    when(() => repo.searchUsers(any()))
        .thenAnswer((_) async => Success([_user(1, 'x')]));
    final cubit = build();
    for (final q in ['aa', 'bb', 'cc', 'dd', 'ee', 'ff', 'gg', 'hh', 'ii']) {
      await cubit.runRecent(q);
    }
    expect(cubit.state.recents.length, 8);
    expect(cubit.state.recents.first, 'ii'); // newest first

    await cubit.runRecent('BB'); // dedupes 'bb'
    expect(cubit.state.recents.where((r) => r.toLowerCase() == 'bb').length, 1);
    expect(cubit.state.recents.first, 'BB');
  });

  test('removeRecent and clearRecents update the list', () async {
    when(() => repo.searchUsers(any()))
        .thenAnswer((_) async => Success([_user(1, 'x')]));
    final cubit = build();
    await cubit.runRecent('one');
    await cubit.runRecent('two');
    cubit.removeRecent('one');
    expect(cubit.state.recents, ['two']);
    cubit.clearRecents();
    expect(cubit.state.recents, isEmpty);
  });

  test('loads cached recents on construction', () {
    when(() => storage.getString(any())).thenReturn('["alpha","beta"]');
    final cubit = build();
    expect(cubit.state.recents, ['alpha', 'beta']);
  });
}
