import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:charmi_insta_freelancing/core/config/app_config.dart';
import 'package:charmi_insta_freelancing/core/error/app_exception.dart';
import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/models/user.dart';
import 'package:charmi_insta_freelancing/core/storage/storage_keys.dart';
import 'package:charmi_insta_freelancing/core/storage/storage_manager.dart';
import 'package:charmi_insta_freelancing/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:charmi_insta_freelancing/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:charmi_insta_freelancing/features/auth/domain/entities/auth_session.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

class _MockStorage extends Mock implements StorageManager {}

void main() {
  late _MockRemote remote;
  late _MockStorage storage;
  late AuthRepositoryImpl repo;
  final original = AppConfig.current;

  const user = User(id: 1, name: 'Alice', roles: ['user']);
  const session = AuthSession(user: user, token: 'tok_123');

  setUp(() {
    remote = _MockRemote();
    storage = _MockStorage();
    repo = AuthRepositoryImpl(remote, storage);
    AppConfig.current = AppConfig.dev.copyWith(baseUrl: 'https://api.test');
    when(() => storage.writeSecure(any(), any())).thenAnswer((_) async {});
    when(() => storage.setString(any(), any())).thenAnswer((_) async => true);
    when(() => storage.clearSession()).thenAnswer((_) async {});
  });
  tearDown(() => AppConfig.current = original);

  test('login success persists token + user and returns session', () async {
    when(() => remote.login(identifier: any(named: 'identifier'), password: any(named: 'password')))
        .thenAnswer((_) async => session);

    final res = await repo.login(identifier: 'a@b.co', password: 'password');

    expect(res.isSuccess, isTrue);
    verify(() => storage.writeSecure(StorageKeys.authToken, 'tok_123')).called(1);
    verify(() => storage.setString(StorageKeys.cachedUserJson, any())).called(1);
  });

  test('login failure does not persist and returns mapped failure', () async {
    when(() => remote.login(identifier: any(named: 'identifier'), password: any(named: 'password')))
        .thenThrow(const AppException('bad creds', statusCode: 422));

    final res = await repo.login(identifier: 'a@b.co', password: 'x');

    expect(res.failureOrNull, isA<ValidationFailure>());
    verifyNever(() => storage.writeSecure(any(), any()));
  });

  test('register returns the pending user and persists NO token', () async {
    const pending = User(
      id: 5,
      name: 'Jane Doe',
      businessName: 'Doe Transport',
      approvalStatus: 'pending',
      roles: ['user'],
    );
    when(() => remote.register(
          name: any(named: 'name'),
          username: any(named: 'username'),
          businessName: any(named: 'businessName'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
          gstNumber: any(named: 'gstNumber'),
          panNumber: any(named: 'panNumber'),
          aadhaarNumber: any(named: 'aadhaarNumber'),
          referralCode: any(named: 'referralCode'),
          password: any(named: 'password'),
          passwordConfirmation: any(named: 'passwordConfirmation'),
        )).thenAnswer((_) async => pending);

    final res = await repo.register(
      name: 'Jane Doe',
      username: 'jane',
      businessName: 'Doe Transport',
      phone: '9876543210',
      email: 'jane@example.com',
      gstNumber: '27AAPFU0939F1ZV',
      password: 'password',
      passwordConfirmation: 'password',
    );

    expect(res.isSuccess, isTrue);
    expect(res.valueOrNull!.isPending, isTrue);
    verifyNever(() => storage.writeSecure(any(), any()));
  });

  test('register maps a 422 to a ValidationFailure', () async {
    when(() => remote.register(
          name: any(named: 'name'),
          username: any(named: 'username'),
          businessName: any(named: 'businessName'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
          gstNumber: any(named: 'gstNumber'),
          panNumber: any(named: 'panNumber'),
          aadhaarNumber: any(named: 'aadhaarNumber'),
          referralCode: any(named: 'referralCode'),
          password: any(named: 'password'),
          passwordConfirmation: any(named: 'passwordConfirmation'),
        )).thenThrow(const AppException('taken', statusCode: 422));

    final res = await repo.register(
      name: 'Jane',
      username: 'jane',
      businessName: 'Doe',
      phone: '9876543210',
      email: 'jane@example.com',
      gstNumber: '27AAPFU0939F1ZV',
      password: 'password',
      passwordConfirmation: 'password',
    );

    expect(res.failureOrNull, isA<ValidationFailure>());
  });

  test('logout clears local session even when the API call throws', () async {
    when(() => remote.logout()).thenThrow(const AppException('network'));
    await repo.logout();
    verify(() => storage.clearSession()).called(1);
  });

  test('cachedUser decodes stored JSON, returns null on garbage', () {
    when(() => storage.getString(StorageKeys.cachedUserJson))
        .thenReturn('{"id":2,"name":"Bob","roles":["creator"]}');
    expect(repo.cachedUser()!.isCreator, isTrue);

    when(() => storage.getString(StorageKeys.cachedUserJson)).thenReturn('not json');
    expect(repo.cachedUser(), isNull);
  });

  test('hasToken reflects stored token presence', () async {
    when(() => storage.readSecure(StorageKeys.authToken)).thenAnswer((_) async => 'tok');
    expect(await repo.hasToken(), isTrue);
    when(() => storage.readSecure(StorageKeys.authToken)).thenAnswer((_) async => null);
    expect(await repo.hasToken(), isFalse);
  });
}
