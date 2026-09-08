import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/network/api_response.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/wallet/domain/entities/wallet.dart';
import 'package:charmi_insta_freelancing/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:charmi_insta_freelancing/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:charmi_insta_freelancing/features/wallet/presentation/cubit/transactions_cubit.dart';
import 'package:charmi_insta_freelancing/features/wallet/presentation/cubit/wallet_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepo extends Mock implements WalletRepository {}

WalletTransaction _tx(int id, {bool credit = true}) =>
    WalletTransaction(id: id, isCredit: credit, reason: 'demo_topup', amount: 100, balanceAfter: 100);

PaginatedResponse<WalletTransaction> _page(List<WalletTransaction> items, {bool more = false}) =>
    PaginatedResponse(items: items, meta: PaginationMeta(currentPage: 1, lastPage: more ? 5 : 1));

void main() {
  group('entities', () {
    test('Wallet.fromJson reads balance/costs/flags', () {
      final w = Wallet.fromJson(const {
        'credit_balance': 100,
        'post_credit_cost': 10,
        'boost_credit_cost': 20,
        'broadcast_credit_cost': 15,
        'currency': 'INR',
        'razorpay_configured': false,
        'demo_topup_enabled': true,
        'demo_topup_credits': 100,
      });
      expect(w.creditBalance, 100);
      expect(w.postCost, 10);
      expect(w.razorpayConfigured, isFalse);
      expect(w.demoTopupEnabled, isTrue);
    });

    test('CreditPackage parses amount as double', () {
      final p = CreditPackage.fromJson(const {
        'id': 1, 'name': 'Starter', 'credits': 50, 'amount': 49.0, 'currency': 'INR',
      });
      expect(p.credits, 50);
      expect(p.amount, 49.0);
    });

    test('WalletTransaction labels reasons and marks credit/debit', () {
      final debit = WalletTransaction.fromJson(const {
        'id': 1, 'type': 'debit', 'reason': 'post_load', 'amount': 10, 'balance_after': 90,
      });
      expect(debit.isCredit, isFalse);
      expect(debit.label, 'Posted a listing');

      final credit = WalletTransaction.fromJson(const {
        'id': 2, 'type': 'credit', 'reason': 'demo_topup', 'amount': 100, 'balance_after': 100,
      });
      expect(credit.isCredit, isTrue);
      expect(credit.label, 'Demo top-up');
    });
  });

  group('WalletCubit', () {
    late _MockWalletRepo repo;
    setUp(() => repo = _MockWalletRepo());

    test('loads wallet + packages', () async {
      when(() => repo.getWallet())
          .thenAnswer((_) async => const Success(Wallet(creditBalance: 100, postCost: 10)));
      when(() => repo.getPackages()).thenAnswer((_) async =>
          const Success([CreditPackage(id: 1, name: 'Starter', credits: 50, amount: 49)]));
      final cubit = WalletCubit(repo);
      await cubit.load();
      expect(cubit.state.status, WalletStatus.loaded);
      expect(cubit.state.wallet?.creditBalance, 100);
      expect(cubit.state.packages.length, 1);
    });

    test('wallet failure → error (does not fetch packages)', () async {
      when(() => repo.getWallet())
          .thenAnswer((_) async => const Err(NetworkFailure('offline')));
      final cubit = WalletCubit(repo);
      await cubit.load();
      expect(cubit.state.status, WalletStatus.error);
      verifyNever(() => repo.getPackages());
    });

    test('packages failure is non-fatal (wallet still loads)', () async {
      when(() => repo.getWallet())
          .thenAnswer((_) async => const Success(Wallet(creditBalance: 5)));
      when(() => repo.getPackages())
          .thenAnswer((_) async => const Err(ServerFailure('nope')));
      final cubit = WalletCubit(repo);
      await cubit.load();
      expect(cubit.state.status, WalletStatus.loaded);
      expect(cubit.state.packages, isEmpty);
    });
  });

  group('TransactionsCubit', () {
    late _MockWalletRepo repo;
    setUp(() => repo = _MockWalletRepo());

    test('load populates and paginates', () async {
      when(() => repo.getTransactions(page: 1))
          .thenAnswer((_) async => Success(_page([_tx(1)], more: true)));
      when(() => repo.getTransactions(page: 2))
          .thenAnswer((_) async => Success(_page([_tx(2, credit: false)])));
      final cubit = TransactionsCubit(repo);
      await cubit.load();
      expect(cubit.state.status, TxStatus.loaded);
      await cubit.loadMore();
      expect(cubit.state.items.map((t) => t.id), [1, 2]);
    });

    test('empty → empty status', () async {
      when(() => repo.getTransactions(page: 1))
          .thenAnswer((_) async => Success(_page([])));
      final cubit = TransactionsCubit(repo);
      await cubit.load();
      expect(cubit.state.status, TxStatus.empty);
    });
  });
}
