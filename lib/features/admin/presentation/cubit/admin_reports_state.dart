part of 'admin_reports_cubit.dart';

enum ReportsStatus { initial, loading, loaded, empty, error }

class AdminReportsState extends Equatable {
  const AdminReportsState({
    this.status = ReportsStatus.initial,
    this.filter,
    this.reports = const [],
    this.errorMessage,
  });

  final ReportsStatus status;

  /// The active status filter, or null for the "All" tab (no status filter).
  final ReportStatus? filter;
  final List<Report> reports;
  final String? errorMessage;

  AdminReportsState copyWith({
    ReportsStatus? status,
    List<Report>? reports,
    String? errorMessage,
  }) {
    return AdminReportsState(
      status: status ?? this.status,
      filter: filter,
      reports: reports ?? this.reports,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// A distinct copy that also swaps the [filter] (which may become null).
  AdminReportsState withFilter(ReportStatus? filter, {ReportsStatus? status}) {
    return AdminReportsState(
      status: status ?? this.status,
      filter: filter,
      reports: const [],
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, filter, reports, errorMessage];
}
