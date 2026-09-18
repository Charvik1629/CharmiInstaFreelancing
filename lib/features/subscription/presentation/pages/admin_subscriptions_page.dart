import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/sub_request_status.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_request.dart';
import '../cubit/admin_sub_plans_cubit.dart';
import '../cubit/admin_sub_requests_cubit.dart';
import 'plan_form_sheet.dart';

/// Admin · Subscriptions (design). Two sections — Requests (approve/reject) and
/// Plans (CRUD + the global enforcement toggle).
class AdminSubscriptionsPage extends StatefulWidget {
  const AdminSubscriptionsPage({super.key});

  @override
  State<AdminSubscriptionsPage> createState() => _AdminSubscriptionsPageState();
}

class _AdminSubscriptionsPageState extends State<AdminSubscriptionsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AdminSubRequestsCubit>()..load()),
        BlocProvider(create: (_) => sl<AdminSubPlansCubit>()..load()),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Subscriptions')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppSegmented(
                segments: const ['Requests', 'Plans'],
                selectedIndex: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: _tab == 0 ? const _RequestsTab() : const _PlansTab(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Requests ───────────────────────────

class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: BlocBuilder<AdminSubRequestsCubit, AdminSubRequestsState>(
            buildWhen: (p, c) => p.filter != c.filter,
            builder: (context, state) => AppSegmented(
              segments: const ['Pending', 'Approved', 'Rejected'],
              selectedIndex: SubRequestStatus.values.indexOf(state.filter),
              onChanged: (i) => context
                  .read<AdminSubRequestsCubit>()
                  .setFilter(SubRequestStatus.values[i]),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: BlocConsumer<AdminSubRequestsCubit, AdminSubRequestsState>(
            listenWhen: (p, c) =>
                p.errorMessage != c.errorMessage && c.errorMessage != null,
            listener: (context, state) =>
                AppOverlays.snack(context, state.errorMessage!),
            builder: (context, state) {
              switch (state.status) {
                case ReqStatus.initial:
                case ReqStatus.loading:
                  return const LoadingView();
                case ReqStatus.error:
                  return ErrorView(
                    message: state.errorMessage ?? 'Could not load requests',
                    onRetry: () => context.read<AdminSubRequestsCubit>().load(),
                  );
                case ReqStatus.empty:
                  return EmptyView(
                    title: 'Nothing here',
                    subtitle: 'No ${state.filter.label.toLowerCase()} requests.',
                    icon: Icons.inbox_outlined,
                  );
                case ReqStatus.loaded:
                  return RefreshIndicator(
                    onRefresh: () =>
                        context.read<AdminSubRequestsCubit>().refresh(),
                    child: ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      itemCount: state.requests.length,
                      itemBuilder: (context, i) => _RequestCard(
                        request: state.requests[i],
                        filter: state.filter,
                        busy: state.actingOnId == state.requests[i].id,
                      ),
                    ),
                  );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.filter,
    required this.busy,
  });

  final SubscriptionRequest request;
  final SubRequestStatus filter;
  final bool busy;

  Future<void> _reject(BuildContext context) async {
    final cubit = context.read<AdminSubRequestsCubit>();
    final note = await _askNote(context);
    if (note == null) return; // cancelled
    final ok = await cubit.reject(request, note: note.isEmpty ? null : note);
    if (context.mounted && ok) AppOverlays.snack(context, 'Request rejected');
  }

  Future<String?> _askNote(BuildContext context) {
    return AppOverlays.prompt(
      context,
      title: 'Reject request',
      hint: 'Enter reason (optional)',
      maxLines: 3,
      confirmLabel: 'Reject',
    );
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final nex = context.nexveero;
    final user = request.user;
    final title = user?.businessName ?? user?.name ?? 'User #${user?.id ?? '?'}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: nex.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(name: title, imageUrl: user?.avatarUrl, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: texts.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      [
                        if (request.plan != null) request.plan!.name,
                        if (request.createdAt != null)
                          request.createdAt!.timeAgo,
                      ].join(' · '),
                      style: texts.bodySmall
                          ?.copyWith(color: nex.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (filter == SubRequestStatus.pending) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Approve',
                    isLoading: busy,
                    onPressed: () =>
                        context.read<AdminSubRequestsCubit>().approve(request),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: 'Reject',
                    variant: AppButtonVariant.outline,
                    onPressed: busy ? null : () => _reject(context),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                filter.label,
                if ((request.adminNote ?? '').isNotEmpty)
                  '· ${request.adminNote}',
              ].join(' '),
              style: texts.labelSmall?.copyWith(
                color: filter == SubRequestStatus.approved
                    ? nex.success
                    : nex.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── Plans ───────────────────────────

class _PlansTab extends StatelessWidget {
  const _PlansTab();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminSubPlansCubit, AdminSubPlansState>(
      listenWhen: (p, c) =>
          p.errorMessage != c.errorMessage && c.errorMessage != null,
      listener: (context, state) =>
          AppOverlays.snack(context, state.errorMessage!),
      builder: (context, state) {
        if (state.status == PlansStatus.loading ||
            state.status == PlansStatus.initial) {
          return const LoadingView();
        }
        if (state.status == PlansStatus.error) {
          return ErrorView(
            message: state.errorMessage ?? 'Could not load plans',
            onRetry: () => context.read<AdminSubPlansCubit>().load(),
          );
        }
        return RefreshIndicator(
          onRefresh: () => context.read<AdminSubPlansCubit>().refresh(),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _EnforcementCard(
                enabled: state.enforcementEnabled,
                saving: state.savingEnforcement,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text('PLANS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.nexveero.textSecondary,
                            letterSpacing: 1)),
                  ),
                  TextButton.icon(
                    onPressed: () => _openForm(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add plan'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (state.plans.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Text('No plans yet. Add one to get started.',
                        style: TextStyle(color: context.nexveero.textSecondary)),
                  ),
                )
              else
                ...state.plans.map((p) => _PlanCard(plan: p)),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _openForm(BuildContext context, {SubscriptionPlan? plan}) {
    final cubit = context.read<AdminSubPlansCubit>();
    return AppOverlays.sheet<void>(
      context,
      builder: (_) => PlanFormSheet(cubit: cubit, plan: plan),
    );
  }
}

class _EnforcementCard extends StatelessWidget {
  const _EnforcementCard({required this.enabled, required this.saving});
  final bool enabled;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: nex.border),
      ),
      child: Row(
        children: [
          Icon(Icons.policy_outlined, color: nex.iconInactive),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Require a subscription', style: texts.titleSmall),
                Text(
                  'When on, users must have an active plan to use the app.',
                  style: texts.bodySmall?.copyWith(color: nex.textSecondary),
                ),
              ],
            ),
          ),
          if (saving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: enabled,
              onChanged: (v) =>
                  context.read<AdminSubPlansCubit>().setEnforcement(v),
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final SubscriptionPlan plan;

  Future<void> _delete(BuildContext context) async {
    final ok = await AppOverlays.confirm(
      context,
      title: 'Delete plan?',
      message: '"${plan.name}" will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await context.read<AdminSubPlansCubit>().deletePlan(plan.id);
    if (context.mounted && done) AppOverlays.snack(context, 'Plan deleted');
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: nex.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.name, style: texts.titleSmall)),
              if (!plan.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: nex.elevated,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text('Inactive',
                      style: texts.labelSmall
                          ?.copyWith(color: nex.textSecondary)),
                ),
            ],
          ),
          if ((plan.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(plan.description!,
                style: texts.bodySmall?.copyWith(color: nex.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text('${plan.durationDays} days · order ${plan.sortOrder}',
              style: texts.labelSmall?.copyWith(color: nex.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _PlansTab._openForm(context, plan: plan),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () => _delete(context),
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
