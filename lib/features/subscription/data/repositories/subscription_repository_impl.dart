import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_request.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_remote_data_source.dart';

class SubscriptionRepositoryImpl
    with BaseRepository
    implements SubscriptionRepository {
  SubscriptionRepositoryImpl(this._remote);

  final SubscriptionRemoteDataSource _remote;

  @override
  Future<Result<Subscription>> getSubscription() =>
      guard(_remote.getSubscription);

  @override
  Future<Result<List<SubscriptionPlan>>> getPlans() =>
      guard(_remote.getPlans);

  @override
  Future<Result<SubscriptionRequest>> requestPlan(int planId) =>
      guard(() => _remote.requestPlan(planId));
}
