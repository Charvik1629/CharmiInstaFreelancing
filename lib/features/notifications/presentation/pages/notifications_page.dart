import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/app_notification.dart';
import '../cubit/notifications_cubit.dart';

/// Notifications (design). A real inbox wired to `GET /notifications`; until that
/// endpoint is live it degrades to the "all caught up" gated state.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<NotificationsCubit>()..load(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              if (state.status != NotifStatus.loaded || !state.hasUnread) {
                return const SizedBox.shrink();
              }
              return TextButton(
                onPressed: () => context.read<NotificationsCubit>().markAllRead(),
                child: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          switch (state.status) {
            case NotifStatus.initial:
            case NotifStatus.loading:
              return const LoadingView();
            case NotifStatus.error:
              return ErrorView(
                message: state.errorMessage ?? 'Could not load notifications',
                onRetry: () => context.read<NotificationsCubit>().load(),
              );
            case NotifStatus.gated:
            case NotifStatus.empty:
              return _CaughtUp(gated: state.status == NotifStatus.gated);
            case NotifStatus.loaded:
              return RefreshIndicator(
                onRefresh: () => context.read<NotificationsCubit>().refresh(),
                child: _list(context, state.items),
              );
          }
        },
      ),
    );
  }

  Widget _list(BuildContext context, List<AppNotification> items) {
    final today = <AppNotification>[];
    final earlier = <AppNotification>[];
    final now = DateTime.now();
    for (final n in items) {
      final d = n.createdAt;
      final isToday = d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
      (isToday ? today : earlier).add(n);
    }
    return ListView(
      children: [
        if (today.isNotEmpty) ...[
          const _SectionLabel('Today'),
          for (final n in today) _NotifRow(n: n),
        ],
        if (earlier.isNotEmpty) ...[
          const _SectionLabel('Earlier'),
          for (final n in earlier) _NotifRow(n: n),
        ],
      ],
    );
  }
}

class _CaughtUp extends StatelessWidget {
  const _CaughtUp({required this.gated});
  final bool gated;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(
          child: EmptyView(
            title: 'All caught up',
            subtitle: 'Requests, offers, approvals and system updates show up here.',
            icon: Icons.notifications_none,
          ),
        ),
        if (gated)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'In-app notifications turn on once the backend endpoint is connected.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.nexveero.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: .5,
                color: context.nexveero.textSecondary)),
      );
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({required this.n});
  final AppNotification n;

  (IconData, Color, Color) _style(BuildContext context) {
    final nex = context.nexveero;
    return switch (n.type) {
      'approval' => (Icons.verified_outlined, nex.success, const Color(0x1F1FA971)),
      'offer' => (Icons.local_offer_outlined, nex.gradientStart, const Color(0x1F6C47FF)),
      'question' => (Icons.chat_bubble_outline, nex.info, const Color(0x1F3B82F6)),
      'boost' => (Icons.rocket_launch_outlined, nex.warning, const Color(0x1FF59E0B)),
      'credit' => (Icons.savings_outlined, nex.success, const Color(0x1F1FA971)),
      _ => (Icons.notifications_none, nex.gradientStart, const Color(0x1F6C47FF)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final (icon, fg, bg) = _style(context);
    final texts = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => context.read<NotificationsCubit>().open(n),
      child: Container(
        color: n.read ? null : nex.elevated,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title,
                      style: texts.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if ((n.body ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(n.body!,
                          style: texts.bodySmall
                              ?.copyWith(color: nex.textSecondary)),
                    ),
                  if (n.createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(n.createdAt!.timeAgo,
                          style: texts.labelSmall
                              ?.copyWith(color: nex.iconInactive)),
                    ),
                ],
              ),
            ),
            if (!n.read)
              Container(
                margin: const EdgeInsets.only(top: 6, left: 8),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: nex.gradientStart, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
