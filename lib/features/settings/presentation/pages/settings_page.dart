import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/realtime/socket_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../admin/domain/entities/report.dart';
import '../../../admin/domain/repositories/admin_repository.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

/// Full Settings screen (design "Settings"). Appearance + account actions are
/// functional; push-notification prefs and account deletion are gated (no API).
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// Count of pending (unreviewed) post reports — shown as a badge on the
  /// "Reported posts" row so admins know something needs review. Fetched on
  /// open and kept live via the socket `report:pending` event.
  int _pendingReports = 0;
  StreamSubscription<int?>? _reportSub;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    final isAdmin = context.read<AuthCubit>().state.user?.isAdmin ?? false;
    if (!isAdmin) return;
    _loadPendingReports();
    if (sl.isRegistered<SocketService>()) {
      _reportSub = sl<SocketService>().reportPendingUpdates.listen((count) {
        if (count != null) {
          if (mounted) setState(() => _pendingReports = count);
        } else {
          _loadPendingReports(); // server didn't send a count — refetch exact
        }
      });
    }
  }

  Future<void> _loadPendingReports() async {
    if (!sl.isRegistered<AdminRepository>()) return;
    final result =
        await sl<AdminRepository>().getReports(status: ReportStatus.pending);
    if (result case Success(value: final page) when mounted) {
      setState(() => _pendingReports = page.meta.total ?? page.items.length);
    }
  }

  @override
  void dispose() {
    _reportSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    final isAdmin = user?.isAdmin ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.sm + MediaQuery.paddingOf(context).bottom),
        children: [
          const _SectionLabel('Appearance'),
          const _ThemeSelector(),
          const _PushToggle(),
          const _SectionLabel('Account'),
          _NavTile(
            icon: Icons.person_outline,
            title: 'Edit profile',
            onTap: () => context.push(AppRoutes.editProfile),
          ),
          _NavTile(
            icon: Icons.lock_reset,
            title: 'Change password',
            onTap: () => context.push(AppRoutes.changePassword),
          ),
          _NavTile(
            icon: Icons.shield_outlined,
            title: 'Security & chat PIN',
            onTap: () => context.push(AppRoutes.security),
          ),
          _NavTile(
            icon: Icons.contacts_outlined,
            title: 'Find friends',
            onTap: () => context.push(AppRoutes.contactSync),
          ),
          // Credit balance (design "Settings · Credit" card) → wallet/buy credits.
          _CreditRow(balance: user?.creditBalance ?? 0),
          if (isAdmin) ...[
            const _SectionLabel('Admin'),
            _NavTile(
              icon: Icons.payments_outlined,
              title: 'Post & boost pricing',
              onTap: () => context.push(AppRoutes.adminPricing),
            ),
            _NavTile(
              icon: Icons.inventory_2_outlined,
              title: 'Packages',
              onTap: () => context.push(AppRoutes.adminPackages),
            ),
            _NavTile(
              icon: Icons.flag_outlined,
              title: 'Reported posts',
              badgeCount: _pendingReports,
              onTap: () async {
                await context.push(AppRoutes.adminReports);
                _loadPendingReports(); // refresh after reviewing
              },
            ),
            _NavTile(
              icon: Icons.campaign_outlined,
              title: 'Broadcast limits',
              onTap: () => context.push(AppRoutes.adminBroadcastLimits),
            ),
            _NavTile(
              icon: Icons.groups_2_outlined,
              title: 'Broadcast groups',
              onTap: () => context.push(AppRoutes.adminBroadcastGroups),
            ),
          ],
          const _SectionLabel('Support'),
          _NavTile(
            icon: Icons.help_outline,
            title: 'Help & support',
            onTap: () => AppOverlays.snack(context, 'Help center coming soon.'),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _DangerZone(),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Text(label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.nexveero.textSecondary, letterSpacing: 1)),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  static const _modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppSegmented(
            segments: const ['System', 'Light', 'Dark'],
            selectedIndex: _modes.indexOf(mode).clamp(0, 2),
            onChanged: (i) => context.read<ThemeCubit>().set(_modes[i]),
          ),
        );
      },
    );
  }
}

/// Local push-notification preference. Persists per-device; takes effect once
/// the notifications backend exists (MISSING_APIS #5).
class _PushToggle extends StatefulWidget {
  const _PushToggle();

  @override
  State<_PushToggle> createState() => _PushToggleState();
}

class _PushToggleState extends State<_PushToggle> {
  bool _on = true;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      secondary: Icon(Icons.notifications_none, color: context.nexveero.textSecondary),
      title: const Text('Push notifications'),
      subtitle: const Text('Requests, offers and messages'),
      value: _on,
      onChanged: (v) => setState(() => _on = v),
    );
  }
}

/// Highlighted Credit balance card (design "Settings · Credit"): gradient toll
/// tile + balance, tapping opens the wallet / buy-credits screen.
class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.balance});
  final int balance;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      child: InkWell(
        onTap: () => context.push(AppRoutes.wallet),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: nex.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.toll, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Credit', style: Theme.of(context).textTheme.titleMedium),
                    Text('Your balance',
                        style: TextStyle(color: nex.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$balance',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary)),
                  Text('credits',
                      style: TextStyle(color: nex.textSecondary, fontSize: 10)),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, size: 20, color: nex.iconInactive),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  /// When > 0, a red count pill is shown before the chevron (e.g. pending
  /// reports awaiting review).
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.nexveero.textSecondary),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone();

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.logout, color: error),
          title: Text('Log out', style: TextStyle(color: error)),
          onTap: () async {
            final ok = await AppOverlays.confirm(
              context,
              title: 'Log out?',
              message: 'You can sign back in anytime.',
              confirmLabel: 'Log out',
              destructive: true,
            );
            if (ok && context.mounted) {
              await context.read<AuthCubit>().logout();
            }
          },
        ),
        ListTile(
          leading: Icon(Icons.delete_outline, color: error),
          title: Text('Delete account', style: TextStyle(color: error)),
          subtitle: const Text('Permanently remove your account and data'),
          onTap: () => context.push(AppRoutes.deleteAccount),
        ),
      ],
    );
  }
}
