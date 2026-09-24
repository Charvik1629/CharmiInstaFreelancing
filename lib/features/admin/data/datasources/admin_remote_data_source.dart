import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/load.dart';
import '../../../../core/models/user.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/report.dart';
import '../../domain/entities/user_approval.dart';

abstract class AdminRemoteDataSource {
  /// GET /admin/reports?status= — paginated moderation queue. A null [status]
  /// fetches every report (the "All" tab), omitting the status filter.
  Future<PaginatedResponse<Report>> getReports({
    ReportStatus? status,
    int page = 1,
  });

  /// GET /loads/{id} — the reported post, for the "View post" action.
  Future<Load> getLoad(int id);

  /// PATCH /admin/reports/{id} — set the review outcome.
  Future<Report> updateReport({
    required int id,
    required ReportStatus status,
    String? note,
  });

  /// GET /admin/users?status= — accounts by approval status (omitted → pending).
  Future<PaginatedResponse<User>> getUsers({
    required UserApprovalStatus status,
    int page = 1,
  });

  /// GET /admin/users/pending-count — badge count of accounts awaiting review.
  Future<int> pendingUsersCount();

  /// POST /admin/users/{id}/approve — approve so the account can log in.
  Future<User> approveUser(int id);

  /// POST /admin/users/{id}/reject — reject the account.
  Future<User> rejectUser(int id);
}

class AdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  AdminRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<PaginatedResponse<Report>> getReports({
    ReportStatus? status,
    int page = 1,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.adminReports,
      query: {
        if (status != null) 'status': status.name,
        'page': page,
        'per_page': AppConstants.defaultPageSize,
      },
    );
    return ApiEnvelope.list(res.data, Report.fromJson);
  }

  @override
  Future<Load> getLoad(int id) async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.load(id));
    return ApiEnvelope.object(res.data, Load.fromJson);
  }

  @override
  Future<Report> updateReport({
    required int id,
    required ReportStatus status,
    String? note,
  }) async {
    final res = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.adminReport(id),
      data: {'status': status.name, 'admin_note': ?note},
    );
    return ApiEnvelope.object(res.data, Report.fromJson);
  }

  @override
  Future<PaginatedResponse<User>> getUsers({
    required UserApprovalStatus status,
    int page = 1,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.adminUsers,
      query: {
        'status': status.name,
        'page': page,
        'per_page': AppConstants.defaultPageSize,
      },
    );
    return ApiEnvelope.list(res.data, User.fromJson);
  }

  @override
  Future<int> pendingUsersCount() async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.adminUsersPendingCount,
    );
    // Shape: { "data": { "total": 2, "pending": 2 } }
    final data = res.data?['data'];
    if (data is Map && data['pending'] is num) {
      return (data['pending'] as num).toInt();
    }
    return 0;
  }

  @override
  Future<User> approveUser(int id) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.adminUserApprove(id),
    );
    return ApiEnvelope.object(res.data, User.fromJson);
  }

  @override
  Future<User> rejectUser(int id) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.adminUserReject(id),
    );
    return ApiEnvelope.object(res.data, User.fromJson);
  }
}
