import '../../../../core/utils/result.dart';
import '../entities/subscription.dart';
import '../entities/subscription_plan.dart';
import '../entities/subscription_request.dart';

abstract class SubscriptionRepository {
  Future<Result<Subscription>> getSubscription();
  Future<Result<List<SubscriptionPlan>>> getPlans();
  Future<Result<SubscriptionRequest>> requestPlan(int planId);
}
