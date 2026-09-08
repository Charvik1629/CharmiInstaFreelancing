import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/user.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

/// "My Profile" (design section 06). Header (avatar, name, verified badge for
/// creators, handle · role, bio), a stats strip, primary actions (Edit / Share)
/// and an account menu. Reads the live user from [AuthCubit], so an edit
/// elsewhere reflects here immediately.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (p, c) => p.user != c.user,
      builder: (context, state) {
        final user = state.user;
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: Text(user == null ? 'Profile' : _handle(user)),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => context.push(AppRoutes.settings),
              ),
            ],
          ),
          body: user == null
              ? const LoadingView()
              : _ProfileBody(user: user),
        );
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        _Header(user: user),
        const SizedBox(height: AppSpacing.xl),
        _StatsStrip(user: user),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Edit profile',
                onPressed: () => context.push(AppRoutes.editProfile),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton(
              label: 'Share',
              icon: Icons.ios_share,
              variant: AppButtonVariant.outline,
              expanded: false,
              onPressed: () => AppOverlays.snack(
                  context, 'Sharing your profile arrives with the Share module.'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        const _AccountMenu(),
        if (user.isAdmin) ...[
          const SizedBox(height: AppSpacing.xl),
          const _AdminMenu(),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    return Column(
      children: [
        AppAvatar(
          name: user.name,
          imageUrl: MediaUrl.resolve(user.avatarUrl),
          size: 92,
          ring: user.canPost, // creators/admins get the gradient story-ring
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                user.name,
                style: texts.titleLarge,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.canPost) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.verified,
                  size: 20, color: Theme.of(context).colorScheme.primary),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${_handle(user)} · ${_roleLabel(user)}',
          style: texts.bodyMedium?.copyWith(color: context.nexveero.textSecondary),
        ),
        if ((user.bio ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            user.bio!,
            style: texts.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.nexveero.elevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          // Design shows a single "Posts" count. The API returns no post count
          // yet (MISSING_APIS #7), so it reads "—" until that lands.
          const _Stat(value: '—', label: 'Posts'),
          _divider(context),
          _Stat(value: '${user.creditBalance}', label: 'Credits'),
          _divider(context),
          _Stat(value: _roleLabel(user), label: 'Role'),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) => Container(
        width: 1,
        height: 28,
        color: context.nexveero.border,
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: texts.titleMedium, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style:
                  texts.labelSmall?.copyWith(color: context.nexveero.textSecondary)),
        ],
      ),
    );
  }
}

/// Account actions. Wallet/help point at their (future) modules for now, but
/// Change password + Log out are live via the settings sheet.
class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Account', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        _MenuTile(
          icon: Icons.local_offer_outlined,
          title: 'Offers',
          onTap: () => context.push(AppRoutes.offers),
        ),
        _MenuTile(
          icon: Icons.receipt_long_outlined,
          title: 'Orders',
          onTap: () => context.push(AppRoutes.orders),
        ),
        _MenuTile(
          icon: Icons.badge_outlined,
          title: 'Business profile',
          onTap: () => context.push(AppRoutes.businessProfile),
        ),
        _MenuTile(
          icon: Icons.storefront_outlined,
          title: 'Business details',
          onTap: () => context.push(AppRoutes.businessDetails),
        ),
        _MenuTile(
          icon: Icons.workspace_premium_outlined,
          title: 'Subscription',
          onTap: () => context.push(AppRoutes.subscription),
        ),
        _MenuTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Wallet & credits',
          onTap: () => context.push(AppRoutes.wallet),
        ),
        _MenuTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          onTap: () => context.push(AppRoutes.settings),
        ),
        _MenuTile(
          icon: Icons.help_outline,
          title: 'Help & support',
          onTap: () => AppOverlays.snack(context, 'Help center coming soon.'),
        ),
      ],
    );
  }
}

/// Admin tools — only rendered for users with the admin role.
class _AdminMenu extends StatelessWidget {
  const _AdminMenu();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Admin', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        _MenuTile(
          icon: Icons.how_to_reg_outlined,
          title: 'User approvals',
          onTap: () => context.push(AppRoutes.adminUsers),
        ),
        _MenuTile(
          icon: Icons.workspace_premium_outlined,
          title: 'Subscriptions',
          onTap: () => context.push(AppRoutes.adminSubscriptions),
        ),
        _MenuTile(
          icon: Icons.sell_outlined,
          title: 'Tags',
          onTap: () => context.push(AppRoutes.adminTags),
        ),
        _MenuTile(
          icon: Icons.flag_outlined,
          title: 'Reported posts',
          onTap: () => context.push(AppRoutes.adminReports),
        ),
        _MenuTile(
          icon: Icons.inventory_2_outlined,
          title: 'Packages',
          onTap: () => context.push(AppRoutes.adminPackages),
        ),
        _MenuTile(
          icon: Icons.tune,
          title: 'Post & boost pricing',
          onTap: () => context.push(AppRoutes.adminPricing),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: context.nexveero.textSecondary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

/// A display handle. The API has no username field, so we derive one from the
/// email local part (falling back to the name) purely for the header look.
String _handle(User user) {
  final base = (user.email != null && user.email!.contains('@'))
      ? user.email!.split('@').first
      : user.name;
  final slug = base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]'), '');
  return '@${slug.isEmpty ? 'user' : slug}';
}

String _roleLabel(User user) {
  if (user.isAdmin) return 'Admin';
  if (user.isCreator) return 'Creator';
  return 'Member';
}
