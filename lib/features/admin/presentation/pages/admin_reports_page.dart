import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/report.dart';
import '../cubit/admin_reports_cubit.dart';

/// Admin · Reported posts (design "Admin · Reported posts", HTML 3409).
/// Moderation queue with All / Pending / Reviewed / Dismissed tabs, a text
/// search, and per-report review / dismiss actions.
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
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: AppTextField(
              hint: 'Search reports',
              prefixIcon: Icons.search,
              onChanged: (v) => context.read<AdminReportsCubit>().search(v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: BlocBuilder<AdminReportsCubit, AdminReportsState>(
              buildWhen: (p, c) => p.filter != c.filter,
              builder: (context, state) => AppSegmented(
                segments: const ['All', 'Pending', 'Reviewed', 'Dismissed'],
                selectedIndex: state.filter == null
                    ? 0
                    : ReportStatus.values.indexOf(state.filter!) + 1,
                onChanged: (i) => context.read<AdminReportsCubit>().setFilter(
                    i == 0 ? null : ReportStatus.values[i - 1]),
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
                    return _EmptyList(
                      subtitle: state.filter == null
                          ? 'No reports.'
                          : 'No ${state.filter!.label.toLowerCase()} reports.',
                    );
                  case ReportsStatus.loaded:
                    final visible = state.visibleReports;
                    if (visible.isEmpty) {
                      return _EmptyList(
                        subtitle: 'No reports match “${state.query.trim()}”.',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () => context.read<AdminReportsCubit>().refresh(),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                        itemCount: visible.length,
                        itemBuilder: (context, i) => _ReportCard(report: visible[i]),
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

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.subtitle});
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    // Pull-to-refresh must work even with no data, so the empty state is a
    // scrollable list wrapped in a RefreshIndicator.
    return RefreshIndicator(
      onRefresh: () => context.read<AdminReportsCubit>().refresh(),
      child: ListView(
        children: [
          const SizedBox(height: 100),
          EmptyView(
            title: 'Nothing here',
            subtitle: subtitle,
            icon: Icons.verified_user_outlined,
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

  /// Opens the reported post's detail; fetches the full [Load] by id first.
  Future<void> _viewPost(BuildContext context) async {
    final cubit = context.read<AdminReportsCubit>();
    final load = await AppLoader.run(cubit.fetchLoad(report.loadId));
    if (!context.mounted) return;
    if (load == null) {
      AppOverlays.snack(context, 'Could not open post');
      return;
    }
    context.push(AppRoutes.postDetail, extra: load);
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final nexveero = context.nexveero;
    final pending = report.status == ReportStatus.pending;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: nexveero.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reporter + time + status badge.
          Row(
            children: [
              AppAvatar(name: report.reporterName ?? 'Reporter', size: 34),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.reporterName ?? 'Unknown reporter',
                        style: texts.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (report.createdAt != null)
                      Text(report.createdAt!.timeAgo,
                          style: texts.labelSmall
                              ?.copyWith(color: nexveero.textSecondary)),
                  ],
                ),
              ),
              _StatusBadge(status: report.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Reported message.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: nexveero.elevated,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('REPORTED MESSAGE',
                    style: texts.labelSmall?.copyWith(
                      color: nexveero.textSecondary,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: AppSpacing.xs),
                Text(report.reason ?? 'No reason provided',
                    style: texts.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Reported post.
          Text(report.loadTitle ?? 'Post #${report.loadId}',
              style: texts.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if ((report.loadAuthorName ?? '').isNotEmpty)
            Text('by ${report.loadAuthorName}',
                style: texts.bodySmall?.copyWith(color: nexveero.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          // Actions.
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'View post',
                  onPressed: () => _viewPost(context),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (pending) ...[
                Expanded(
                  child: AppButton(
                    label: 'Reviewed',
                    variant: AppButtonVariant.tonal,
                    onPressed: () => _act(context, ReportStatus.reviewed),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Dismiss',
                    variant: AppButtonVariant.outline,
                    onPressed: () => _act(context, ReportStatus.dismissed),
                  ),
                ),
              ] else
                Expanded(
                  child: AppButton(
                    label: report.status == ReportStatus.reviewed
                        ? 'Dismiss'
                        : 'Mark reviewed',
                    variant: AppButtonVariant.outline,
                    onPressed: () => _act(
                        context,
                        report.status == ReportStatus.reviewed
                            ? ReportStatus.dismissed
                            : ReportStatus.reviewed),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final nexveero = context.nexveero;
    final color = switch (status) {
      ReportStatus.pending => nexveero.warning,
      ReportStatus.reviewed => nexveero.success,
      ReportStatus.dismissed => nexveero.textSecondary,
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
