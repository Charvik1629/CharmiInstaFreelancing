import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:charmi_insta_freelancing/core/di/injection.dart';
import 'package:charmi_insta_freelancing/core/models/user.dart';
import 'package:charmi_insta_freelancing/core/theme/app_theme.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/auth/domain/entities/auth_session.dart';
import 'package:charmi_insta_freelancing/features/auth/domain/repositories/auth_repository.dart';
import 'package:charmi_insta_freelancing/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:charmi_insta_freelancing/features/auth/presentation/cubit/login_cubit.dart';
import 'package:charmi_insta_freelancing/features/auth/presentation/pages/login_page.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(
        const AuthSession(user: User(id: 0, name: ''), token: ''));
  });

  late _MockAuthRepo repo;

  setUp(() {
    repo = _MockAuthRepo();
    when(() => repo.hasToken()).thenAnswer((_) async => false);
    when(() => repo.persistSession(any())).thenAnswer((_) async {});
    if (sl.isRegistered<LoginCubit>()) sl.unregister<LoginCubit>();
    sl.registerFactory<LoginCubit>(() => LoginCubit(repo));
  });

  tearDown(() => sl.reset());

  Widget harness() {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        GoRoute(path: '/feed', builder: (_, _) => const Scaffold(body: Text('FEED'))),
      ],
    );
    return BlocProvider<AuthCubit>(
      create: (_) => AuthCubit(repo),
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
  }

  testWidgets('empty submit shows validation errors, no API call', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('Log in'));
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    verifyNever(() => repo.login(email: any(named: 'email'), password: any(named: 'password')));
  });

  testWidgets('valid submit calls repository.login', (tester) async {
    when(() => repo.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => const Success(
            AuthSession(user: User(id: 1, name: 'A'), token: 't')));

    await tester.pumpWidget(harness());
    await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.text('Log in'));
    await tester.pump();
    await tester.pump();

    verify(() => repo.login(email: 'a@b.co', password: 'password')).called(1);
  });
}
