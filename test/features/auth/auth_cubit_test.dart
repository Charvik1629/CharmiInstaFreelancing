import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/models/user.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/auth/domain/entities/auth_session.dart';
import 'package:charmi_insta_freelancing/features/auth/domain/repositories/auth_repository.dart';
import 'package:charmi_insta_freelancing/features/auth/presentation/cubit/auth_cubit.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(
        const AuthSession(user: User(id: 0, name: ''), token: ''));
    registerFallbackValue(const User(id: 0, name: ''));
  });

  late _MockAuthRepo repo;
  const user = User(id: 1, name: 'Alice', roles: ['user']);

  setUp(() {
    repo = _MockAuthRepo();
    when(() => repo.logout()).thenAnswer((_) async {});
    when(() => repo.persistSession(any())).thenAnswer((_) async {});
  });

  test('bootstrap with no token → unauthenticated', () async {
    when(() => repo.hasToken()).thenAnswer((_) async => false);
    final cubit = AuthCubit(repo);
    await cubit.bootstrap();
    expect(cubit.state.status, AuthStatus.unauthenticated);
  });

  test('bootstrap with token + fresh me → authenticated with user', () async {
    when(() => repo.hasToken()).thenAnswer((_) async => true);
    when(() => repo.cachedUser()).thenReturn(null);
    when(() => repo.me()).thenAnswer((_) async => const Success(user));
    final cubit = AuthCubit(repo);
    await cubit.bootstrap();
    expect(cubit.state.status, AuthStatus.authenticated);
    expect(cubit.state.user, user);
  });

  test('bootstrap with cached user but me() 401 → logs out', () async {
    when(() => repo.hasToken()).thenAnswer((_) async => true);
    when(() => repo.cachedUser()).thenReturn(user);
    when(() => repo.me()).thenAnswer((_) async => const Err(AuthFailure()));
    final cubit = AuthCubit(repo);
    await cubit.bootstrap();
    verify(() => repo.logout()).called(1);
    expect(cubit.state.status, AuthStatus.unauthenticated);
  });

  test('bootstrap keeps cached session on transient (non-401) error', () async {
    when(() => repo.hasToken()).thenAnswer((_) async => true);
    when(() => repo.cachedUser()).thenReturn(user);
    when(() => repo.me()).thenAnswer((_) async => const Err(NetworkFailure()));
    final cubit = AuthCubit(repo);
    await cubit.bootstrap();
    expect(cubit.state.status, AuthStatus.authenticated);
    verifyNever(() => repo.logout());
  });

  test('onAuthenticated persists and emits authenticated', () async {
    when(() => repo.hasToken()).thenAnswer((_) async => false);
    final cubit = AuthCubit(repo);
    await cubit.onAuthenticated(const AuthSession(user: user, token: 't'));
    verify(() => repo.persistSession(any())).called(1);
    expect(cubit.state.status, AuthStatus.authenticated);
  });

  test('updateUser re-caches and emits the new user when authenticated', () async {
    when(() => repo.hasToken()).thenAnswer((_) async => false);
    when(() => repo.cacheUser(any())).thenAnswer((_) async {});
    final cubit = AuthCubit(repo);
    await cubit.onAuthenticated(const AuthSession(user: user, token: 't'));

    final updated = user.copyWith(name: 'Alice B', bio: 'hi');
    await cubit.updateUser(updated);

    verify(() => repo.cacheUser(updated)).called(1);
    expect(cubit.state.user?.name, 'Alice B');
    expect(cubit.state.user?.bio, 'hi');
  });

  test('updateUser is a no-op when not authenticated', () async {
    when(() => repo.cacheUser(any())).thenAnswer((_) async {});
    final cubit = AuthCubit(repo);
    await cubit.updateUser(user);
    verifyNever(() => repo.cacheUser(any()));
    expect(cubit.state.status, AuthStatus.unknown);
  });
}
