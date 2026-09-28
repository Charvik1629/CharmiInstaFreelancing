import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

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
      padding: EdgeInsets.zero,
      children: [
        _ProfileHeader(user: user, onShare: () => _shareProfile(context, user)),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AccountMenu(),
              if (user.isAdmin) ...[
                const SizedBox(height: AppSpacing.xl),
                const _AdminMenu(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Opens the system share sheet with the profile link.
  Future<void> _shareProfile(BuildContext context, User user) async {
    final link = user.shareUrl ??
        (user.username != null ? 'https://nexveero.com/u/${user.username}' : null);
    if (link == null) {
      AppOverlays.snack(context, 'No profile link available yet.');
      return;
    }
    await SharePlus.instance.share(
      ShareParams(text: '${user.name} on Nexveero\n$link'),
    );
  }
}

/// The design "Business Profile" / "Creator Profile" (own-variant) header:
/// gradient cover with a settings gear, a rounded-square avatar overlapping the
/// cover with a verified/premium ribbon badge, name + verified (+ premium) icon,
/// chips, @handle, bio, a Posts stat, an optional premium card, then Edit/Share.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.onShare});

  final User user;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final topInset = MediaQuery.of(context).padding.top;
    // Premium gets an amber→pink cover; everyone else the brand gradient.
    final cover = user.isPremium
        ? LinearGradient(
            colors: [nex.warning, nex.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : nex.primaryGradient;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover with the settings gear (own profile).
        Container(
          height: topInset + 96,
          decoration: BoxDecoration(gradient: cover),
          padding: EdgeInsets.only(top: topInset),
          child: Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              tooltip: 'Settings',
              onPressed: () => context.push(AppRoutes.settings),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rounded-square avatar overlapping the cover + ribbon badge.
              Transform.translate(
                offset: const Offset(0, -34),
                child: _RibbonAvatar(user: user, background: bg),
              ),
              Transform.translate(
                offset: const Offset(0, -22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(user.name,
                              style: texts.titleLarge,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Icon(Icons.verified, size: 20, color: primary),
                        ],
                        if (user.isPremium) ...[
                          const SizedBox(width: 2),
                          Icon(Icons.workspace_premium,
                              size: 20, color: nex.warning),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // "My Profile" (general): @handle · role. Business chips and
                    // the Go-Premium card live on the dedicated Business Profile
                    // page (Profile → "Business Profile"), not here.
                    Text('${_atHandle(user)} · ${_roleLabel(user)}',
                        style: texts.bodyMedium
                            ?.copyWith(color: nex.textSecondary)),
                    if ((user.bio ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(user.bio!, style: texts.bodyMedium),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _StatsRow(user: user),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Edit profile',
                            onPressed: () => context.push(AppRoutes.editProfile),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _SquareIconButton(
                          icon: Icons.ios_share,
                          onTap: onShare,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rounded-square gradient/photo avatar (design radius 24) with a small ribbon
/// badge (verified, or amber premium) at its bottom-right corner.
class _RibbonAvatar extends StatelessWidget {
  const _RibbonAvatar({required this.user, required this.background});

  final User user;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final primary = Theme.of(context).colorScheme.primary;
    final imageUrl = MediaUrl.resolve(user.avatarUrl);
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    const size = 82.0;

    final initials = () {
      final parts = user.name
          .trim()
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty);
      if (parts.isEmpty) return '?';
      return parts.take(2).map((p) => p[0].toUpperCase()).join();
    }();

    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: hasImage ? null : nex.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: background, width: 4),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 26)),
                  )
                : Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 26)),
          ),
          if (user.isVerified || user.isPremium)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  user.isPremium ? Icons.workspace_premium : Icons.verified,
                  size: 18,
                  color: user.isPremium ? nex.warning : primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Verified / Business / Premium Customer chips (only those that apply).
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(value: '${user.postsCount}', label: 'Posts')),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: context.nexveero.elevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Text(value, style: texts.titleMedium),
          const SizedBox(height: 2),
          Text(label,
              style: texts.labelSmall
                  ?.copyWith(color: context.nexveero.textSecondary)),
        ],
      ),
    );
  }
}

/// Premium status card (business profiles). Premium → "Premium active · Manage";
/// otherwise a dashed "Go Premium" card. Both route to the subscription screen.
/// No renewal date is shown because the profile payload doesn't carry one.
class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: context.nexveero.elevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
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

/// The public `@handle` — the server username when present, else derived.
String _atHandle(User user) {
  final u = user.username;
  if (u != null && u.trim().isNotEmpty) return '@${u.trim()}';
  return _handle(user);
}
