import '../../../../core/models/load.dart';
import '../../../../core/models/user.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/utils/result.dart';
import '../entities/report.dart';
import '../entities/user_approval.dart';

abstract class AdminRepository {
  /// A null [status] returns all reports (the "All" tab).
  Future<Result<PaginatedResponse<Report>>> getReports({
    ReportStatus? status,
    int page,
  });

  /// Fetches the reported post so the moderator can open its detail.
  Future<Result<Load>> getLoad(int id);

  Future<Result<Report>> updateReport({
    required int id,
    required ReportStatus status,
    String? note,
  });

  Future<Result<PaginatedResponse<User>>> getUsers({
    required UserApprovalStatus status,
    int page,
  });

  Future<Result<int>> pendingUsersCount();

  Future<Result<User>> approveUser(int id);

  Future<Result<User>> rejectUser(int id);
}
