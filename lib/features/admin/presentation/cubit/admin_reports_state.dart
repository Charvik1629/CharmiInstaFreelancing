part of 'admin_reports_cubit.dart';

enum ReportsStatus { initial, loading, loaded, empty, error }

class AdminReportsState extends Equatable {
  const AdminReportsState({
    this.status = ReportsStatus.initial,
    this.filter = ReportStatus.pending,
    this.reports = const [],
    this.errorMessage,
  });

  final ReportsStatus status;
  final ReportStatus filter;
  final List<Report> reports;
  final String? errorMessage;

  AdminReportsState copyWith({
    ReportsStatus? status,
    ReportStatus? filter,
    List<Report>? reports,
    String? errorMessage,
  }) {
    return AdminReportsState(
      status: status ?? this.status,
      filter: filter ?? this.filter,
      reports: reports ?? this.reports,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, filter, reports, errorMessage];
}
