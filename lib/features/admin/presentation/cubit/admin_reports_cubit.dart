import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/admin_repository.dart';

part 'admin_reports_state.dart';

/// Drives the admin moderation queue: Pending / Reviewed / Dismissed tabs, with
/// per-report actions that PATCH the status.
class AdminReportsCubit extends Cubit<AdminReportsState> {
  AdminReportsCubit(this._repository) : super(const AdminReportsState());

  final AdminRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: ReportsStatus.loading));
    final result = await _repository.getReports(status: state.filter, page: 1);
    switch (result) {
      case Success(value: final res):
        emit(state.copyWith(
          status: res.items.isEmpty ? ReportsStatus.empty : ReportsStatus.loaded,
          reports: res.items,
        ));
      case Err(failure: final f):
        emit(state.copyWith(status: ReportsStatus.error, errorMessage: f.message));
    }
  }

  Future<void> refresh() => load();

  Future<void> setFilter(ReportStatus filter) async {
    if (filter == state.filter) return;
    emit(state.copyWith(filter: filter, reports: const [], status: ReportsStatus.loading));
    await load();
  }

  /// Reviews/dismisses a report and drops it from the current (Pending) list.
  Future<bool> updateStatus(Report report, ReportStatus status) async {
    final result = await _repository.updateReport(id: report.id, status: status);
    if (result.isSuccess) {
      // If we're viewing a different tab than the new status, remove the row.
      final remaining =
          state.reports.where((r) => r.id != report.id).toList();
      emit(state.copyWith(
        reports: remaining,
        status: remaining.isEmpty ? ReportsStatus.empty : ReportsStatus.loaded,
      ));
      return true;
    }
    return false;
  }
}
