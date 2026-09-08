import '../../../../core/models/user.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/report.dart';
import '../../domain/entities/user_approval.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_data_source.dart';

class AdminRepositoryImpl with BaseRepository implements AdminRepository {
  AdminRepositoryImpl(this._remote);

  final AdminRemoteDataSource _remote;

  @override
  Future<Result<PaginatedResponse<Report>>> getReports({
    required ReportStatus status,
    int page = 1,
  }) =>
      guard(() => _remote.getReports(status: status, page: page));

  @override
  Future<Result<Report>> updateReport({
    required int id,
    required ReportStatus status,
    String? note,
  }) =>
      guard(() => _remote.updateReport(id: id, status: status, note: note));

  @override
  Future<Result<PaginatedResponse<User>>> getUsers({
    required UserApprovalStatus status,
    int page = 1,
  }) =>
      guard(() => _remote.getUsers(status: status, page: page));

  @override
  Future<Result<int>> pendingUsersCount() =>
      guard(_remote.pendingUsersCount);

  @override
  Future<Result<User>> approveUser(int id) =>
      guard(() => _remote.approveUser(id));

  @override
  Future<Result<User>> rejectUser(int id) =>
      guard(() => _remote.rejectUser(id));
}
