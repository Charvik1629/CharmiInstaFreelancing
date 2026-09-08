import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/report.dart';
import '../cubit/admin_reports_cubit.dart';

/// Admin · Reported posts (design). Moderation queue with Pending / Reviewed /
/// Dismissed tabs and per-report actions.
class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AdminReportsCubit>()..load(),
      child: const _ReportsView(),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reported posts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: BlocBuilder<AdminReportsCubit, AdminReportsState>(
              buildWhen: (p, c) => p.filter != c.filter,
              builder: (context, state) => AppSegmented(
                segments: const ['Pending', 'Reviewed', 'Dismissed'],
                selectedIndex: ReportStatus.values.indexOf(state.filter),
                onChanged: (i) =>
                    context.read<AdminReportsCubit>().setFilter(ReportStatus.values[i]),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<AdminReportsCubit, AdminReportsState>(
              builder: (context, state) {
                switch (state.status) {
                  case ReportsStatus.loading:
                  case ReportsStatus.initial:
                    return const LoadingView();
                  case ReportsStatus.error:
                    return ErrorView(
                      message: state.errorMessage ?? 'Could not load reports',
                      onRetry: () => context.read<AdminReportsCubit>().load(),
                    );
                  case ReportsStatus.empty:
                    return EmptyView(
                      title: 'Nothing here',
                      subtitle: 'No ${state.filter.label.toLowerCase()} reports.',
                      icon: Icons.verified_user_outlined,
                    );
                  case ReportsStatus.loaded:
                    return RefreshIndicator(
                      onRefresh: () => context.read<AdminReportsCubit>().refresh(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        itemCount: state.reports.length,
                        itemBuilder: (context, i) =>
                            _ReportCard(report: state.reports[i]),
                      ),
                    );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final Report report;

  Future<void> _act(BuildContext context, ReportStatus status) async {
    final ok = await context.read<AdminReportsCubit>().updateStatus(report, status);
    if (ok && context.mounted) {
      AppOverlays.snack(context, 'Report ${status.label.toLowerCase()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final pending = report.status == ReportStatus.pending;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.nexveero.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 18, color: context.nexveero.warning),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(report.reason ?? 'Reported',
                    style: texts.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.nexveero.elevated,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.loadTitle ?? 'Post #${report.loadId}',
                    style: texts.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if ((report.loadAuthorName ?? '').isNotEmpty)
                  Text('by ${report.loadAuthorName}',
                      style: texts.bodySmall?.copyWith(color: context.nexveero.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    if ((report.reporterName ?? '').isNotEmpty) 'Reported by ${report.reporterName}',
                    if (report.createdAt != null) report.createdAt!.timeAgo,
                  ].join(' · '),
                  style: texts.labelSmall?.copyWith(color: context.nexveero.textSecondary),
                ),
              ),
              if (!pending)
                Text(report.status.label,
                    style: texts.labelSmall?.copyWith(color: context.nexveero.textSecondary)),
            ],
          ),
          if (pending) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Mark reviewed',
                    variant: AppButtonVariant.tonal,
                    onPressed: () => _act(context, ReportStatus.reviewed),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: 'Dismiss',
                    variant: AppButtonVariant.outline,
                    onPressed: () => _act(context, ReportStatus.dismissed),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
