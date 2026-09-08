import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_plan.dart';
import '../cubit/subscription_cubit.dart';

/// User · Subscription (design "Go Premium" / "Subscription required"). Shows the
/// current standing and the plans the user can request; requesting a plan creates
/// a pending admin request (plans have no price — access is admin-granted).
class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SubscriptionCubit>()..load(),
      child: const _SubscriptionView(),
    );
  }
}

class _SubscriptionView extends StatelessWidget {
  const _SubscriptionView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: BlocConsumer<SubscriptionCubit, SubscriptionState>(
        listenWhen: (p, c) =>
            p.errorMessage != c.errorMessage && c.errorMessage != null,
        listener: (context, state) =>
            AppOverlays.snack(context, state.errorMessage!),
        builder: (context, state) {
          switch (state.status) {
            case SubStatus.initial:
            case SubStatus.loading:
              return const LoadingView();
            case SubStatus.error:
              return ErrorView(
                message: state.errorMessage ?? 'Could not load subscription',
                onRetry: () => context.read<SubscriptionCubit>().load(),
              );
            case SubStatus.loaded:
              final sub = state.subscription;
              return RefreshIndicator(
                onRefresh: () => context.read<SubscriptionCubit>().refresh(),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    if (sub != null) _StatusCard(sub: sub),
                    const SizedBox(height: AppSpacing.xl),
                    Text('PLANS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.nexveero.textSecondary,
                            letterSpacing: 1)),
                    const SizedBox(height: AppSpacing.sm),
                    if (state.selectablePlans.isEmpty)
                      Text('No plans available right now.',
                          style: TextStyle(color: context.nexveero.textSecondary))
                    else
                      ...state.selectablePlans.map(
                        (p) => _PlanCard(
                          plan: p,
                          current: sub?.plan?.id == p.id && (sub?.isActive ?? false),
                          disabled: (sub?.hasPendingRequest ?? false) ||
                              (sub?.isActive ?? false),
                          busy: state.requestingPlanId == p.id,
                        ),
                      ),
                  ],
                ),
              );
          }
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.sub});
  final Subscription sub;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;

    late final IconData icon;
    late final Color color;
    late final String title;
    late final String subtitle;

    if (sub.isActive) {
      icon = Icons.workspace_premium;
      color = nex.success;
      title = 'Premium active';
      subtitle = [
        if (sub.plan != null) sub.plan!.name,
        if (sub.endsAt != null) 'Renews / ends on ${_date(sub.endsAt!)}',
      ].join(' · ');
    } else if (sub.hasPendingRequest) {
      icon = Icons.hourglass_top_rounded;
      color = nex.teal;
      title = 'Request pending';
      subtitle =
          'An admin is reviewing your request${sub.pendingRequest?.plan != null ? ' for ${sub.pendingRequest!.plan!.name}' : ''}.';
    } else if (sub.isRequired) {
      icon = Icons.lock_outline;
      color = nex.warning;
      title = 'Subscription required';
      subtitle = 'Choose a plan below to keep using Nexveero.';
    } else {
      icon = Icons.workspace_premium_outlined;
      color = nex.primaryGradient.colors.first;
      title = 'Go Premium';
      subtitle = 'Unlock the full Nexveero experience with a plan.';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: texts.titleMedium),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: texts.bodySmall
                          ?.copyWith(color: nex.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.current,
    required this.disabled,
    required this.busy,
  });

  final SubscriptionPlan plan;
  final bool current;
  final bool disabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: current ? nex.success : nex.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.name, style: texts.titleSmall)),
              if (current)
                Text('Current',
                    style: texts.labelSmall?.copyWith(
                        color: nex.success, fontWeight: FontWeight.w700)),
            ],
          ),
          if ((plan.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(plan.description!,
                style: texts.bodySmall?.copyWith(color: nex.textSecondary)),
          ],
          if (plan.durationDays > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('${plan.durationDays} days',
                style: texts.labelSmall?.copyWith(color: nex.textSecondary)),
          ],
          if (!current) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Request plan',
              isLoading: busy,
              expanded: false,
              onPressed: disabled
                  ? null
                  : () => context.read<SubscriptionCubit>().requestPlan(plan),
            ),
          ],
        ],
      ),
    );
  }
}
