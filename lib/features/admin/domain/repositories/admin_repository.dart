import '../../../../core/models/user.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/utils/result.dart';
import '../entities/report.dart';
import '../entities/user_approval.dart';

abstract class AdminRepository {
  Future<Result<PaginatedResponse<Report>>> getReports({
    required ReportStatus status,
    int page,
  });

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
