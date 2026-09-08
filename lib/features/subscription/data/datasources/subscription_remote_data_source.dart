import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_request.dart';

abstract class SubscriptionRemoteDataSource {
  /// GET /subscription — current enforcement state, plan, dates, pending request.
  Future<Subscription> getSubscription();

  /// GET /subscription/plans — plans the user can request.
  Future<List<SubscriptionPlan>> getPlans();

  /// POST /subscription/requests — ask an admin to grant a plan.
  Future<SubscriptionRequest> requestPlan(int planId);
}

class SubscriptionRemoteDataSourceImpl implements SubscriptionRemoteDataSource {
  SubscriptionRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<Subscription> getSubscription() async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.subscription,
    );
    return ApiEnvelope.object(res.data, Subscription.fromJson);
  }

  @override
  Future<List<SubscriptionPlan>> getPlans() async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.subscriptionPlans,
    );
    return ApiEnvelope.list(res.data, SubscriptionPlan.fromJson).items;
  }

  @override
  Future<SubscriptionRequest> requestPlan(int planId) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.subscriptionRequests,
      data: {'subscription_plan_id': planId},
    );
    return ApiEnvelope.object(res.data, SubscriptionRequest.fromJson);
  }
}
