import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';
import '../entities/sub_request_status.dart';
import '../entities/subscription_plan.dart';
import '../entities/subscription_request.dart';

abstract class AdminSubscriptionRepository {
  Future<Result<List<SubscriptionPlan>>> getPlans();
  Future<Result<SubscriptionPlan>> createPlan({
    required String name,
    String? description,
    required int durationDays,
    required bool isActive,
    required int sortOrder,
  });
  Future<Result<SubscriptionPlan>> updatePlan({
    required int id,
    required String name,
    String? description,
    required int durationDays,
    required bool isActive,
    required int sortOrder,
  });
  Future<Result<void>> deletePlan(int id);

  Future<Result<List<SubscriptionRequest>>> getRequests(SubRequestStatus status);
  Future<Result<SubscriptionRequest>> approveRequest(int id);
  Future<Result<SubscriptionRequest>> rejectRequest(int id, {String? note});

  Future<Result<bool>> getEnforcement();
  Future<Result<bool>> setEnforcement(bool enabled);

  Future<Result<User>> assignUser(int userId, int planId);
  Future<Result<void>> removeUser(int userId);
}
