part of 'admin_reports_cubit.dart';

enum ReportsStatus { initial, loading, loaded, empty, error }

class AdminReportsState extends Equatable {
  const AdminReportsState({
    this.status = ReportsStatus.initial,
    this.filter,
    this.reports = const [],
    this.query = '',
    this.errorMessage,
  });

  final ReportsStatus status;

  /// The active status filter, or null for the "All" tab (no status filter).
  final ReportStatus? filter;
  final List<Report> reports;

  /// Client-side text search over reporter / post title / reason.
  final String query;
  final String? errorMessage;

  /// Reports after applying the text [query] (the status filter is applied
  /// server-side). Used by the listing so search never hits the network.
  List<Report> get visibleReports {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return reports;
    return reports.where((r) {
      return (r.reporterName ?? '').toLowerCase().contains(q) ||
          (r.loadTitle ?? '').toLowerCase().contains(q) ||
          (r.loadAuthorName ?? '').toLowerCase().contains(q) ||
          (r.reason ?? '').toLowerCase().contains(q);
    }).toList();
  }

  AdminReportsState copyWith({
    ReportsStatus? status,
    List<Report>? reports,
    String? query,
    String? errorMessage,
  }) {
    return AdminReportsState(
      status: status ?? this.status,
      filter: filter,
      reports: reports ?? this.reports,
      query: query ?? this.query,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// A distinct copy that also swaps the [filter] (which may become null).
  AdminReportsState withFilter(ReportStatus? filter, {ReportsStatus? status}) {
    return AdminReportsState(
      status: status ?? this.status,
      filter: filter,
      reports: const [],
      query: query,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, filter, reports, query, errorMessage];
}
