import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/models/user.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/auth/domain/repositories/auth_repository.dart';
import 'package:charmi_insta_freelancing/features/auth/presentation/cubit/auth_form_state.dart';
import 'package:charmi_insta_freelancing/features/auth/presentation/cubit/login_cubit.dart';
import 'package:charmi_insta_freelancing/features/auth/presentation/cubit/register_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  group('RegisterCubit', () {
    const pending = User(
      id: 5,
      name: 'Jane',
      businessName: 'Doe Transport',
      approvalStatus: 'pending',
      roles: ['user'],
    );

    test('success emits the pending user (no session)', () async {
      when(() => repo.register(
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
          )).thenAnswer((_) async => const Success(pending));

      final cubit = RegisterCubit(repo);
      await cubit.submit(
        name: 'Jane',
        username: 'jane',
        businessName: 'Doe Transport',
        phone: '9876543210',
        email: 'jane@example.com',
        gstNumber: '27AAPFU0939F1ZV',
        password: 'password',
        passwordConfirmation: 'password',
      );

      expect(cubit.state.status, FormStatus.success);
      expect(cubit.state.user?.isPending, isTrue);
      expect(cubit.state.session, isNull);
    });

    test('422 surfaces per-field errors', () async {
      when(() => repo.register(
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
          )).thenAnswer((_) async => const Err(ValidationFailure(
            'invalid',
            fieldErrors: {
              'email': ['taken']
            },
          )));

      final cubit = RegisterCubit(repo);
      await cubit.submit(
        name: 'Jane',
        username: 'jane',
        businessName: 'Doe',
        phone: '9876543210',
        email: 'jane@example.com',
        gstNumber: '27AAPFU0939F1ZV',
        password: 'password',
        passwordConfirmation: 'password',
      );

      expect(cubit.state.status, FormStatus.failure);
      expect(cubit.state.fieldError('email'), 'taken');
    });
  });

  group('LoginCubit', () {
    test('403 (pending/rejected) sets the forbidden flag', () async {
      when(() => repo.login(
              identifier: any(named: 'identifier'), password: any(named: 'password')))
          .thenAnswer((_) async =>
              const Err(ForbiddenFailure('Your account is pending approval.')));

      final cubit = LoginCubit(repo);
      await cubit.submit(identifier: 'a@b.co', password: 'password');

      expect(cubit.state.status, FormStatus.failure);
      expect(cubit.state.forbidden, isTrue);
    });

    test('a non-403 failure does not set forbidden', () async {
      when(() => repo.login(
              identifier: any(named: 'identifier'), password: any(named: 'password')))
          .thenAnswer((_) async => const Err(ValidationFailure('bad creds')));

      final cubit = LoginCubit(repo);
      await cubit.submit(identifier: 'a@b.co', password: 'x');

      expect(cubit.state.forbidden, isFalse);
    });
  });
}
