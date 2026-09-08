import '../../../../core/models/user.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/sub_request_status.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_request.dart';
import '../../domain/repositories/admin_subscription_repository.dart';
import '../datasources/admin_subscription_remote_data_source.dart';

class AdminSubscriptionRepositoryImpl
    with BaseRepository
    implements AdminSubscriptionRepository {
  AdminSubscriptionRepositoryImpl(this._remote);

  final AdminSubscriptionRemoteDataSource _remote;

  @override
  Future<Result<List<SubscriptionPlan>>> getPlans() => guard(_remote.getPlans);

  @override
  Future<Result<SubscriptionPlan>> createPlan({
    required String name,
    String? description,
    required int durationDays,
    required bool isActive,
    required int sortOrder,
  }) =>
      guard(() => _remote.createPlan(
            name: name,
            description: description,
            durationDays: durationDays,
            isActive: isActive,
            sortOrder: sortOrder,
          ));

  @override
  Future<Result<SubscriptionPlan>> updatePlan({
    required int id,
    required String name,
    String? description,
    required int durationDays,
    required bool isActive,
    required int sortOrder,
  }) =>
      guard(() => _remote.updatePlan(
            id: id,
            name: name,
            description: description,
            durationDays: durationDays,
            isActive: isActive,
            sortOrder: sortOrder,
          ));

  @override
  Future<Result<void>> deletePlan(int id) => guard(() => _remote.deletePlan(id));

  @override
  Future<Result<List<SubscriptionRequest>>> getRequests(
          SubRequestStatus status) =>
      guard(() => _remote.getRequests(status));

  @override
  Future<Result<SubscriptionRequest>> approveRequest(int id) =>
      guard(() => _remote.approveRequest(id));

  @override
  Future<Result<SubscriptionRequest>> rejectRequest(int id, {String? note}) =>
      guard(() => _remote.rejectRequest(id, note: note));

  @override
  Future<Result<bool>> getEnforcement() => guard(_remote.getEnforcement);

  @override
  Future<Result<bool>> setEnforcement(bool enabled) =>
      guard(() => _remote.setEnforcement(enabled));

  @override
  Future<Result<User>> assignUser(int userId, int planId) =>
      guard(() => _remote.assignUser(userId, planId));

  @override
  Future<Result<void>> removeUser(int userId) =>
      guard(() => _remote.removeUser(userId));
}
