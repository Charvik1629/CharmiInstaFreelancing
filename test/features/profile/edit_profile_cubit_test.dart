import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/models/user.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/profile/domain/entities/profile_update.dart';
import 'package:charmi_insta_freelancing/features/profile/domain/repositories/profile_repository.dart';
import 'package:charmi_insta_freelancing/features/profile/presentation/cubit/edit_profile_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepo extends Mock implements ProfileRepository {}

const _user = User(
  id: 1,
  name: 'Maya Kapoor',
  email: 'maya@example.com',
  bio: 'Storyteller',
  phone: '+100',
  roles: ['creator'],
);

void main() {
  late _MockProfileRepo repo;

  setUpAll(() => registerFallbackValue(const ProfileUpdate()));
  setUp(() => repo = _MockProfileRepo());

  EditProfileCubit build() => EditProfileCubit(repo, _user);

  test('seeds the form from the current user', () {
    final cubit = build();
    expect(cubit.state.name, 'Maya Kapoor');
    expect(cubit.state.bio, 'Storyteller');
    expect(cubit.state.phone, '+100');
    expect(cubit.state.canSubmit, isTrue);
  });

  test('empty name blocks submit', () {
    final cubit = build();
    cubit.setName('   ');
    expect(cubit.state.canSubmit, isFalse);
  });

  test('no changes → immediate success without calling the API', () async {
    final cubit = build();
    await cubit.submit();
    expect(cubit.state.status, EditStatus.success);
    expect(cubit.state.saved, _user);
    verifyNever(() => repo.updateProfile(any()));
  });

  test('sends only the changed fields', () async {
    when(() => repo.updateProfile(any()))
        .thenAnswer((_) async => Success(_user.copyWith(name: 'Maya K')));
    final cubit = build();
    cubit.setName('Maya K'); // changed
    // bio & phone untouched
    await cubit.submit();

    final update = verify(() => repo.updateProfile(captureAny())).captured.single
        as ProfileUpdate;
    expect(update.name, 'Maya K');
    expect(update.bio, isNull);
    expect(update.phone, isNull);
    expect(cubit.state.status, EditStatus.success);
  });

  test('a new avatar is always sent even if text is unchanged', () async {
    when(() => repo.updateProfile(any()))
        .thenAnswer((_) async => Success(_user));
    final cubit = build();
    cubit.setAvatar('/tmp/a.jpg');
    await cubit.submit();

    final update = verify(() => repo.updateProfile(captureAny())).captured.single
        as ProfileUpdate;
    expect(update.hasAvatar, isTrue);
    expect(update.avatarPath, '/tmp/a.jpg');
  });

  test('422 maps field errors to first message', () async {
    when(() => repo.updateProfile(any())).thenAnswer(
      (_) async => const Err(ValidationFailure('Invalid', fieldErrors: {
        'phone': ['Phone is invalid', 'too long'],
      })),
    );
    final cubit = build();
    cubit.setPhone('bad');
    await cubit.submit();

    expect(cubit.state.status, EditStatus.failure);
    expect(cubit.state.fieldErrors['phone'], 'Phone is invalid');
  });

  test('generic failure surfaces the message', () async {
    when(() => repo.updateProfile(any()))
        .thenAnswer((_) async => const Err(ServerFailure('nope')));
    final cubit = build();
    cubit.setBio('new bio');
    await cubit.submit();

    expect(cubit.state.status, EditStatus.failure);
    expect(cubit.state.errorMessage, 'nope');
  });
}
