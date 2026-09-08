import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/subscription/domain/entities/sub_request_status.dart';
import 'package:charmi_insta_freelancing/features/subscription/domain/entities/subscription_plan.dart';
import 'package:charmi_insta_freelancing/features/subscription/domain/entities/subscription_request.dart';
import 'package:charmi_insta_freelancing/features/subscription/domain/repositories/admin_subscription_repository.dart';
import 'package:charmi_insta_freelancing/features/subscription/presentation/cubit/admin_sub_plans_cubit.dart';
import 'package:charmi_insta_freelancing/features/subscription/presentation/cubit/admin_sub_requests_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AdminSubscriptionRepository {}

const _monthly = SubscriptionPlan(id: 1, name: 'Monthly', durationDays: 30);
const _req = SubscriptionRequest(id: 18, status: 'pending', plan: _monthly);

void main() {
  late _MockRepo repo;

  setUpAll(() => registerFallbackValue(SubRequestStatus.pending));
  setUp(() => repo = _MockRepo());

  group('AdminSubRequestsCubit', () {
    test('load emits loaded with the pending queue', () async {
      when(() => repo.getRequests(any()))
          .thenAnswer((_) async => const Success([_req]));
      final cubit = AdminSubRequestsCubit(repo);
      await cubit.load();
      expect(cubit.state.status, ReqStatus.loaded);
      expect(cubit.state.requests, const [_req]);
    });

    test('approve drops the row and returns true', () async {
      when(() => repo.getRequests(any()))
          .thenAnswer((_) async => const Success([_req]));
      when(() => repo.approveRequest(18)).thenAnswer(
          (_) async => const Success(SubscriptionRequest(id: 18, status: 'approved')));
      final cubit = AdminSubRequestsCubit(repo);
      await cubit.load();
      final ok = await cubit.approve(_req);
      expect(ok, isTrue);
      expect(cubit.state.requests, isEmpty);
      expect(cubit.state.status, ReqStatus.empty);
    });

    test('reject passes the admin note', () async {
      when(() => repo.getRequests(any()))
          .thenAnswer((_) async => const Success([_req]));
      when(() => repo.rejectRequest(18, note: any(named: 'note'))).thenAnswer(
          (_) async => const Success(SubscriptionRequest(id: 18, status: 'rejected')));
      final cubit = AdminSubRequestsCubit(repo);
      await cubit.load();
      final ok = await cubit.reject(_req, note: 'no proof');
      expect(ok, isTrue);
      verify(() => repo.rejectRequest(18, note: 'no proof')).called(1);
    });

    test('setFilter reloads for the new status', () async {
      when(() => repo.getRequests(SubRequestStatus.pending))
          .thenAnswer((_) async => const Success([_req]));
      when(() => repo.getRequests(SubRequestStatus.approved))
          .thenAnswer((_) async => const Success([]));
      final cubit = AdminSubRequestsCubit(repo);
      await cubit.load();
      await cubit.setFilter(SubRequestStatus.approved);
      expect(cubit.state.filter, SubRequestStatus.approved);
      expect(cubit.state.status, ReqStatus.empty);
    });
  });

  group('AdminSubPlansCubit', () {
    void stubLoad({bool enforced = false}) {
      when(repo.getPlans).thenAnswer((_) async => const Success([_monthly]));
      when(repo.getEnforcement).thenAnswer((_) async => Success(enforced));
    }

    test('load emits plans (sorted) + enforcement flag', () async {
      when(repo.getPlans).thenAnswer((_) async => const Success([
            SubscriptionPlan(id: 2, name: 'Quarterly', sortOrder: 2),
            SubscriptionPlan(id: 1, name: 'Monthly', sortOrder: 1),
          ]));
      when(repo.getEnforcement).thenAnswer((_) async => const Success(true));
      final cubit = AdminSubPlansCubit(repo);
      await cubit.load();
      expect(cubit.state.status, PlansStatus.loaded);
      expect(cubit.state.plans.map((p) => p.id), [1, 2]);
      expect(cubit.state.enforcementEnabled, isTrue);
    });

    test('createPlan appends and re-sorts', () async {
      stubLoad();
      when(() => repo.createPlan(
            name: any(named: 'name'),
            description: any(named: 'description'),
            durationDays: any(named: 'durationDays'),
            isActive: any(named: 'isActive'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer((_) async => const Success(
          SubscriptionPlan(id: 3, name: 'Yearly', sortOrder: 5)));
      final cubit = AdminSubPlansCubit(repo);
      await cubit.load();
      final ok = await cubit.createPlan(
          name: 'Yearly', durationDays: 365, isActive: true, sortOrder: 5);
      expect(ok, isTrue);
      expect(cubit.state.plans.map((p) => p.id), [1, 3]); // sorted by sortOrder
    });

    test('deletePlan removes the row', () async {
      stubLoad();
      when(() => repo.deletePlan(1))
          .thenAnswer((_) async => const Success(null));
      final cubit = AdminSubPlansCubit(repo);
      await cubit.load();
      final ok = await cubit.deletePlan(1);
      expect(ok, isTrue);
      expect(cubit.state.plans, isEmpty);
      expect(cubit.state.status, PlansStatus.empty);
    });

    test('setEnforcement reverts on failure', () async {
      stubLoad(enforced: false);
      when(() => repo.setEnforcement(true))
          .thenAnswer((_) async => const Err(ServerFailure('boom', statusCode: 500)));
      final cubit = AdminSubPlansCubit(repo);
      await cubit.load();
      await cubit.setEnforcement(true);
      expect(cubit.state.enforcementEnabled, isFalse); // reverted
      expect(cubit.state.savingEnforcement, isFalse);
    });
  });
}
