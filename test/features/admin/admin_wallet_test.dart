import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/admin/domain/entities/wallet_package.dart';
import 'package:charmi_insta_freelancing/features/admin/domain/entities/wallet_settings.dart';
import 'package:charmi_insta_freelancing/features/admin/domain/repositories/admin_wallet_repository.dart';
import 'package:charmi_insta_freelancing/features/admin/presentation/cubit/admin_packages_cubit.dart';
import 'package:charmi_insta_freelancing/features/admin/presentation/cubit/admin_wallet_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AdminWalletRepository {}

const _starter =
    WalletPackage(id: 1, name: 'Starter', credits: 50, amountPaise: 4900, sortOrder: 1);
const _popular =
    WalletPackage(id: 2, name: 'Popular', credits: 120, amountPaise: 9900, sortOrder: 2);

void main() {
  late _MockRepo repo;
  setUp(() => repo = _MockRepo());

  group('WalletPackage', () {
    test('amount derives rupees from paise', () {
      expect(_starter.amount, 49.0);
    });
    test('fromJson parses fields', () {
      final p = WalletPackage.fromJson(const {
        'id': 3,
        'name': 'Pro',
        'credits': 300,
        'amount_paise': 19900,
        'is_active': false,
        'sort_order': 3,
      });
      expect(p.amount, 199.0);
      expect(p.isActive, isFalse);
    });
  });

  group('AdminPackagesCubit', () {
    test('load emits loaded sorted by sort order', () async {
      when(repo.getPackages)
          .thenAnswer((_) async => const Success([_popular, _starter]));
      final cubit = AdminPackagesCubit(repo);
      await cubit.load();
      expect(cubit.state.status, PackagesStatus.loaded);
      expect(cubit.state.packages.map((p) => p.id), [1, 2]);
    });

    test('load emits empty', () async {
      when(repo.getPackages).thenAnswer((_) async => const Success([]));
      final cubit = AdminPackagesCubit(repo);
      await cubit.load();
      expect(cubit.state.status, PackagesStatus.empty);
    });

    test('createPackage appends + re-sorts', () async {
      when(repo.getPackages).thenAnswer((_) async => const Success([_popular]));
      when(() => repo.createPackage(
            name: any(named: 'name'),
            credits: any(named: 'credits'),
            amountPaise: any(named: 'amountPaise'),
            isActive: any(named: 'isActive'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer((_) async => const Success(_starter));
      final cubit = AdminPackagesCubit(repo);
      await cubit.load();
      final ok = await cubit.createPackage(
          name: 'Starter',
          credits: 50,
          amountPaise: 4900,
          isActive: true,
          sortOrder: 1);
      expect(ok, isTrue);
      expect(cubit.state.packages.map((p) => p.id), [1, 2]);
    });

    test('deletePackage removes the row', () async {
      when(repo.getPackages)
          .thenAnswer((_) async => const Success([_starter, _popular]));
      when(() => repo.deletePackage(2))
          .thenAnswer((_) async => const Success(null));
      final cubit = AdminPackagesCubit(repo);
      await cubit.load();
      final ok = await cubit.deletePackage(2);
      expect(ok, isTrue);
      expect(cubit.state.packages.map((p) => p.id), [1]);
    });

    test('createPackage failure surfaces message', () async {
      when(repo.getPackages).thenAnswer((_) async => const Success([]));
      when(() => repo.createPackage(
            name: any(named: 'name'),
            credits: any(named: 'credits'),
            amountPaise: any(named: 'amountPaise'),
            isActive: any(named: 'isActive'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer(
          (_) async => const Err(ValidationFailure('amount_paise≥100')));
      final cubit = AdminPackagesCubit(repo);
      await cubit.load();
      final ok = await cubit.createPackage(
          name: 'X', credits: 1, amountPaise: 50, isActive: true, sortOrder: 0);
      expect(ok, isFalse);
      expect(cubit.state.errorMessage, 'amount_paise≥100');
    });
  });

  group('AdminWalletSettingsCubit', () {
    const settings = WalletSettings(postCreditCost: 10, boostCreditCost: 20);

    test('load emits loaded settings', () async {
      when(repo.getSettings).thenAnswer((_) async => const Success(settings));
      final cubit = AdminWalletSettingsCubit(repo);
      await cubit.load();
      expect(cubit.state.status, SettingsStatus.loaded);
      expect(cubit.state.settings!.postCreditCost, 10);
    });

    test('save returns true and updates settings', () async {
      when(repo.getSettings).thenAnswer((_) async => const Success(settings));
      when(() => repo.updateSettings(any())).thenAnswer((_) async =>
          const Success(WalletSettings(postCreditCost: 15, boostCreditCost: 20)));
      final cubit = AdminWalletSettingsCubit(repo);
      await cubit.load();
      final ok = await cubit.save({'post_credit_cost': 15});
      expect(ok, isTrue);
      expect(cubit.state.settings!.postCreditCost, 15);
      expect(cubit.state.saving, isFalse);
    });

    test('save failure keeps saving false and surfaces message', () async {
      when(repo.getSettings).thenAnswer((_) async => const Success(settings));
      when(() => repo.updateSettings(any()))
          .thenAnswer((_) async => const Err(ValidationFailure('bad')));
      final cubit = AdminWalletSettingsCubit(repo);
      await cubit.load();
      final ok = await cubit.save({'post_credit_cost': -1});
      expect(ok, isFalse);
      expect(cubit.state.saving, isFalse);
      expect(cubit.state.errorMessage, 'bad');
    });
  });
}
