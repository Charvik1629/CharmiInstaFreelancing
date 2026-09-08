import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/business_profile_cubit.dart';

/// Business Profile (design) — the viewer's own business page: verified &
/// premium badges, about, products. Products/tags are gated until the backend
/// returns them (BACKEND_REQUIREMENTS B1/C1); badges are live.
class BusinessProfilePage extends StatelessWidget {
  const BusinessProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BusinessProfileCubit>()..load(),
      child: const _BusinessProfileView(),
    );
  }
}

class _BusinessProfileView extends StatelessWidget {
  const _BusinessProfileView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<BusinessProfileCubit, BusinessProfileState>(
        builder: (context, state) {
          if (state.status == BpStatus.loading ||
              state.status == BpStatus.initial) {
            return const LoadingView();
          }
          if (state.status == BpStatus.error || state.user == null) {
            return ErrorView(
              message: state.errorMessage ?? 'Could not load profile',
              onRetry: () => context.read<BusinessProfileCubit>().load(),
            );
          }
          final u = state.user!;
          final nex = context.nexveero;
          final texts = Theme.of(context).textTheme;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(height: 120, decoration: BoxDecoration(gradient: nex.primaryGradient)),
                    Positioned(
                      top: 44, left: 8,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, 82, AppSpacing.lg, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(24)),
                            child: AppAvatar(
                                name: u.businessName ?? u.name,
                                imageUrl: MediaUrl.resolve(u.avatarUrl),
                                size: 78),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Flexible(
                                child: Text(u.businessName ?? u.name,
                                    style: texts.titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (state.isVerified) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.verified, size: 20, color: nex.gradientStart),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            if (state.isVerified) _badge(context, 'Verified', nex.success, const Color(0x1F1FA971)),
                            if (state.isPremium) ...[
                              const SizedBox(width: 6),
                              _badge(context, 'Premium', nex.gradientStart, const Color(0x1F6C47FF)),
                            ],
                          ]),
                          if ((u.bio ?? '').isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(u.bio!, style: texts.bodyMedium?.copyWith(color: nex.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(child: _goPremium(context, state)),
              SliverToBoxAdapter(child: _sectionLabel(context, 'Products')),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(color: context.nexveero.border),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.grid_view_outlined,
                            color: context.nexveero.iconInactive),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Products & tags appear here once you add them in Business '
                            'details (and the backend serves them).',
                            style: TextStyle(color: context.nexveero.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _sectionLabel(context, 'About')),
              SliverToBoxAdapter(child: _about(context, u)),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  Widget _badge(BuildContext c, String t, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(t, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );

  Widget _sectionLabel(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 4),
        child: Text(t, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      );

  Widget _goPremium(BuildContext context, BusinessProfileState state) {
    final active = state.isPremium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
            gradient: context.nexveero.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.workspace_premium, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(active ? "You're Premium" : 'Go Premium',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Sora')),
            ]),
            const SizedBox(height: 6),
            Text(
              active
                  ? 'Premium badge active · boosted placement in View Business.'
                  : 'Unlock the premium badge and boosted placement with a plan.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.push(AppRoutes.subscription),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(11)),
                child: Text(active ? 'Manage subscription' : 'See plans',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Sora')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _about(BuildContext context, u) {
    final nex = context.nexveero;
    Widget row(IconData i, String? v) => (v == null || v.isEmpty)
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Icon(i, size: 17, color: nex.iconInactive),
              const SizedBox(width: 10),
              Expanded(child: Text(v, style: TextStyle(color: nex.textSecondary))),
            ]),
          );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: nex.border),
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(Icons.person_outline, u.name),
          row(Icons.alternate_email, u.email),
          row(Icons.phone_outlined, u.phone),
          row(Icons.badge_outlined, (u.gstNumber ?? '').isNotEmpty ? 'GST ${u.gstNumber}' : null),
        ],
      ),
    );
  }
}
