import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/subscription/domain/entities/subscription.dart';
import 'package:charmi_insta_freelancing/features/subscription/domain/entities/subscription_plan.dart';
import 'package:charmi_insta_freelancing/features/subscription/domain/entities/subscription_request.dart';
import 'package:charmi_insta_freelancing/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:charmi_insta_freelancing/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements SubscriptionRepository {}

const _monthly = SubscriptionPlan(
  id: 1,
  name: 'Monthly',
  description: 'Access for 30 days.',
  durationDays: 30,
);

void main() {
  group('Subscription.fromJson', () {
    test('parses required status with a pending request', () {
      final sub = Subscription.fromJson(const {
        'enabled': true,
        'status': 'required',
        'plan': null,
        'pending_request': {
          'id': 18,
          'status': 'pending',
          'plan': {'id': 1, 'name': 'Monthly', 'duration_days': 30},
        },
      });
      expect(sub.isRequired, isTrue);
      expect(sub.isActive, isFalse);
      expect(sub.hasPendingRequest, isTrue);
      expect(sub.pendingRequest!.plan!.name, 'Monthly');
    });

    test('active subscription with a plan', () {
      final sub = Subscription.fromJson(const {
        'enabled': true,
        'status': 'active',
        'plan': {'id': 2, 'name': 'Quarterly', 'duration_days': 90},
      });
      expect(sub.isActive, isTrue);
      expect(sub.hasPendingRequest, isFalse);
      expect(sub.plan!.name, 'Quarterly');
    });
  });

  group('SubscriptionCubit', () {
    late _MockRepo repo;
    setUp(() => repo = _MockRepo());

    test('load emits loaded with subscription + active plans sorted', () async {
      when(repo.getSubscription).thenAnswer((_) async =>
          const Success(Subscription(enabled: true, status: 'required')));
      when(repo.getPlans).thenAnswer((_) async => const Success([
            SubscriptionPlan(id: 2, name: 'Quarterly', sortOrder: 2),
            SubscriptionPlan(id: 1, name: 'Monthly', sortOrder: 1),
            SubscriptionPlan(id: 3, name: 'Old', isActive: false, sortOrder: 3),
          ]));

      final cubit = SubscriptionCubit(repo);
      await cubit.load();

      expect(cubit.state.status, SubStatus.loaded);
      // inactive plan filtered out, sorted by sortOrder
      expect(cubit.state.selectablePlans.map((p) => p.id), [1, 2]);
    });

    test('load surfaces an error when the status call fails', () async {
      when(repo.getSubscription)
          .thenAnswer((_) async => const Err(NetworkFailure()));
      when(repo.getPlans).thenAnswer((_) async => const Success([]));

      final cubit = SubscriptionCubit(repo);
      await cubit.load();

      expect(cubit.state.status, SubStatus.error);
    });

    test('requestPlan succeeds and reloads with the pending request', () async {
      when(repo.getSubscription).thenAnswer((_) async =>
          const Success(Subscription(enabled: true, status: 'required')));
      when(repo.getPlans).thenAnswer((_) async => const Success([_monthly]));

      final cubit = SubscriptionCubit(repo);
      await cubit.load();

      when(() => repo.requestPlan(1)).thenAnswer((_) async => const Success(
          SubscriptionRequest(id: 18, status: 'pending', plan: _monthly)));
      // After requesting, the reload now reports a pending request.
      when(repo.getSubscription).thenAnswer((_) async => const Success(
            Subscription(
              enabled: true,
              status: 'required',
              pendingRequest:
                  SubscriptionRequest(id: 18, status: 'pending', plan: _monthly),
            ),
          ));

      final ok = await cubit.requestPlan(_monthly);

      expect(ok, isTrue);
      expect(cubit.state.subscription!.hasPendingRequest, isTrue);
      expect(cubit.state.requestingPlanId, isNull);
    });

    test('requestPlan failure returns false and surfaces the message', () async {
      when(repo.getSubscription).thenAnswer((_) async =>
          const Success(Subscription(enabled: true, status: 'required')));
      when(repo.getPlans).thenAnswer((_) async => const Success([_monthly]));
      final cubit = SubscriptionCubit(repo);
      await cubit.load();

      when(() => repo.requestPlan(1)).thenAnswer(
          (_) async => const Err(ValidationFailure('already pending')));

      final ok = await cubit.requestPlan(_monthly);

      expect(ok, isFalse);
      expect(cubit.state.errorMessage, 'already pending');
      expect(cubit.state.requestingPlanId, isNull);
    });
  });
}
