import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/models/user.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/sub_request_status.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_request.dart';

abstract class AdminSubscriptionRemoteDataSource {
  Future<List<SubscriptionPlan>> getPlans();
  Future<SubscriptionPlan> createPlan({
    required String name,
    String? description,
    required int durationDays,
    required bool isActive,
    required int sortOrder,
  });
  Future<SubscriptionPlan> updatePlan({
    required int id,
    required String name,
    String? description,
    required int durationDays,
    required bool isActive,
    required int sortOrder,
  });
  Future<void> deletePlan(int id);

  Future<List<SubscriptionRequest>> getRequests(SubRequestStatus status);
  Future<SubscriptionRequest> approveRequest(int id);
  Future<SubscriptionRequest> rejectRequest(int id, {String? note});

  /// GET /admin/subscriptions/settings → the global enforcement flag.
  Future<bool> getEnforcement();

  /// PUT /admin/subscriptions/settings → set the global enforcement flag.
  Future<bool> setEnforcement(bool enabled);

  Future<User> assignUser(int userId, int planId);
  Future<void> removeUser(int userId);
}

class AdminSubscriptionRemoteDataSourceImpl
    implements AdminSubscriptionRemoteDataSource {
  AdminSubscriptionRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  Map<String, dynamic> _planBody({
    required String name,
    String? description,
    required int durationDays,
    required bool isActive,
    required int sortOrder,
  }) =>
      {
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        'duration_days': durationDays,
        'is_active': isActive,
        'sort_order': sortOrder,
      };

  @override
  Future<List<SubscriptionPlan>> getPlans() async {
    final res =
        await _client.get<Map<String, dynamic>>(ApiEndpoints.adminSubPlans);
    return ApiEnvelope.list(res.data, SubscriptionPlan.fromJson).items;
  }

  @override
  Future<SubscriptionPlan> createPlan({
    required String name,
    String? description,
    required int durationDays,
    required bool isActive,
    required int sortOrder,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.adminSubPlans,
      data: _planBody(
        name: name,
        description: description,
        durationDays: durationDays,
        isActive: isActive,
        sortOrder: sortOrder,
      ),
    );
    return ApiEnvelope.object(res.data, SubscriptionPlan.fromJson);
  }

  @override
  Future<SubscriptionPlan> updatePlan({
    required int id,
    required String name,
    String? description,
    required int durationDays,
    required bool isActive,
    required int sortOrder,
  }) async {
    final res = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.adminSubPlan(id),
      data: _planBody(
        name: name,
        description: description,
        durationDays: durationDays,
        isActive: isActive,
        sortOrder: sortOrder,
      ),
    );
    return ApiEnvelope.object(res.data, SubscriptionPlan.fromJson);
  }

  @override
  Future<void> deletePlan(int id) async {
    await _client.delete<dynamic>(ApiEndpoints.adminSubPlan(id));
  }

  @override
  Future<List<SubscriptionRequest>> getRequests(SubRequestStatus status) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.adminSubRequests,
      query: {'status': status.name},
    );
    return ApiEnvelope.list(res.data, SubscriptionRequest.fromJson).items;
  }

  @override
  Future<SubscriptionRequest> approveRequest(int id) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.adminSubRequestApprove(id),
    );
    return ApiEnvelope.object(res.data, SubscriptionRequest.fromJson);
  }

  @override
  Future<SubscriptionRequest> rejectRequest(int id, {String? note}) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.adminSubRequestReject(id),
      data: {if (note != null && note.isNotEmpty) 'admin_note': note},
    );
    return ApiEnvelope.object(res.data, SubscriptionRequest.fromJson);
  }

  @override
  Future<bool> getEnforcement() async {
    final res =
        await _client.get<Map<String, dynamic>>(ApiEndpoints.adminSubSettings);
    return _readEnabled(res.data);
  }

  @override
  Future<bool> setEnforcement(bool enabled) async {
    final res = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.adminSubSettings,
      data: {'subscription_enabled': enabled},
    );
    return _readEnabled(res.data);
  }

  bool _readEnabled(Map<String, dynamic>? body) {
    final data = body?['data'];
    if (data is Map && data['subscription_enabled'] is bool) {
      return data['subscription_enabled'] as bool;
    }
    return false;
  }

  @override
  Future<User> assignUser(int userId, int planId) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.adminSubUserAssign(userId),
      data: {'subscription_plan_id': planId},
    );
    return ApiEnvelope.object(res.data, User.fromJson);
  }

  @override
  Future<void> removeUser(int userId) async {
    await _client.delete<dynamic>(ApiEndpoints.adminSubUserRemove(userId));
  }
}
