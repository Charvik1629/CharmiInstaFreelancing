import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/models/user.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/profile/domain/entities/profile_update.dart';
import 'package:charmi_insta_freelancing/features/profile/domain/repositories/profile_repository.dart';
import 'package:charmi_insta_freelancing/features/profile/presentation/cubit/business_details_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepo extends Mock implements ProfileRepository {}

void main() {
  late _MockProfileRepo repo;

  setUpAll(() => registerFallbackValue(const ProfileUpdate()));
  setUp(() => repo = _MockProfileRepo());

  test('ProfileUpdate.isEmpty reflects business fields too', () {
    expect(const ProfileUpdate().isEmpty, isTrue);
    expect(const ProfileUpdate(businessName: 'Kapoor Traders').isEmpty, isFalse);
    expect(const ProfileUpdate(products: ['Cotton']).isEmpty, isFalse);
    expect(const ProfileUpdate(tagIds: [1, 2]).isEmpty, isFalse);
  });

  test('submit success emits saved user', () async {
    when(() => repo.updateProfile(any())).thenAnswer(
        (_) async => const Success(User(id: 1, name: 'Maya', businessName: 'KT')));
    final cubit = BusinessDetailsCubit(repo);
    await cubit.submit(const ProfileUpdate(businessName: 'KT', city: 'Surat'));
    expect(cubit.state.status, BdStatus.success);
    expect(cubit.state.saved?.businessName, 'KT');
  });

  test('submit forwards the full business payload', () async {
    when(() => repo.updateProfile(any()))
        .thenAnswer((_) async => const Success(User(id: 1, name: 'Maya')));
    final cubit = BusinessDetailsCubit(repo);
    await cubit.submit(const ProfileUpdate(
      businessName: 'KT',
      companyType: 'Proprietorship',
      products: ['Cotton', 'Silk'],
      tagIds: [1, 4],
      socialLinks: {'instagram': '@kt'},
    ));
    final sent =
        verify(() => repo.updateProfile(captureAny())).captured.single as ProfileUpdate;
    expect(sent.companyType, 'Proprietorship');
    expect(sent.products, ['Cotton', 'Silk']);
    expect(sent.tagIds, [1, 4]);
    expect(sent.socialLinks, {'instagram': '@kt'});
  });

  test('422 surfaces per-field errors', () async {
    when(() => repo.updateProfile(any())).thenAnswer((_) async => const Err(
        ValidationFailure('invalid', fieldErrors: {
          'business_name': ['required']
        })));
    final cubit = BusinessDetailsCubit(repo);
    await cubit.submit(const ProfileUpdate(city: 'Surat'));
    expect(cubit.state.status, BdStatus.failure);
    expect(cubit.state.fieldErrors['business_name'], 'required');
  });
}
