import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

enum ReportStatus {
  pending,
  reviewed,
  dismissed;

  static ReportStatus fromApi(String? raw) => switch (raw) {
        'reviewed' => ReportStatus.reviewed,
        'dismissed' => ReportStatus.dismissed,
        _ => ReportStatus.pending,
      };

  String get label => switch (this) {
        ReportStatus.pending => 'Pending',
        ReportStatus.reviewed => 'Reviewed',
        ReportStatus.dismissed => 'Dismissed',
      };
}

/// A moderation report on a post (GET /admin/reports).
class Report extends Equatable {
  const Report({
    required this.id,
    required this.loadId,
    this.reason,
    this.status = ReportStatus.pending,
    this.reporterName,
    this.loadTitle,
    this.loadAuthorName,
    this.createdAt,
  });

  final int id;
  final int loadId;
  final String? reason;
  final ReportStatus status;
  final String? reporterName;
  final String? loadTitle;
  final String? loadAuthorName;
  final DateTime? createdAt;

  Report copyWith({ReportStatus? status}) => Report(
        id: id,
        loadId: loadId,
        reason: reason,
        status: status ?? this.status,
        reporterName: reporterName,
        loadTitle: loadTitle,
        loadAuthorName: loadAuthorName,
        createdAt: createdAt,
      );

  factory Report.fromJson(Map<String, dynamic> json) {
    final load = json.asMap('load');
    return Report(
      id: json.asIntOr('id', 0),
      loadId: json.asIntOr('load_id', 0),
      reason: json.asString('body'),
      status: ReportStatus.fromApi(json.asString('status')),
      reporterName: json.asMap('reporter')?.asString('name'),
      loadTitle: load?.asString('title'),
      loadAuthorName: load?.asMap('author')?.asString('name'),
      createdAt: json.asDate('created_at'),
    );
  }

  @override
  List<Object?> get props =>
      [id, loadId, reason, status, reporterName, loadTitle, loadAuthorName, createdAt];
}
