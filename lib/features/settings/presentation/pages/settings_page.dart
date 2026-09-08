import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

/// Full Settings screen (design "Settings"). Appearance + account actions are
/// functional; push-notification prefs and account deletion are gated (no API).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
          const _SectionLabel('Support'),
          _NavTile(
            icon: Icons.help_outline,
            title: 'Help & support',
            onTap: () => AppOverlays.snack(context, 'Help center coming soon.'),
          ),
          _NavTile(
            icon: Icons.info_outline,
            title: 'About Nexveero',
            trailing: Text('v1.0.0',
                style: TextStyle(color: context.nexveero.textSecondary)),
            onTap: () => AppOverlays.snack(context, 'Nexveero — built with Flutter.'),
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

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.nexveero.textSecondary),
      title: Text(title),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
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
          onTap: () => AppOverlays.snack(
              context, 'Account deletion needs a backend endpoint (see MISSING_APIS.md).'),
        ),
      ],
    );
  }
}
