import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/business.dart';
import '../../domain/repositories/business_directory_repository.dart';
import '../cubit/business_directory_cubit.dart';

/// Business directory (design: search products, tags, business). Backed by
/// `GET /businesses`; boost via `POST /businesses/{id}/boost`.
class BusinessDirectoryPage extends StatelessWidget {
  const BusinessDirectoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          BusinessDirectoryCubit(sl<BusinessDirectoryRepository>())..load(),
      child: const _DirectoryView(),
    );
  }
}

class _DirectoryView extends StatelessWidget {
  const _DirectoryView();

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: Container(
            decoration: BoxDecoration(
              color: nex.elevated,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: nex.iconInactive),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    onChanged: (v) =>
                        context.read<BusinessDirectoryCubit>().onQueryChanged(v),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search products, tags, business…',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: BlocBuilder<BusinessDirectoryCubit, BusinessDirectoryState>(
        builder: (context, state) {
          switch (state.status) {
            case BizDirStatus.initial:
            case BizDirStatus.loading:
              return const ListSkeleton();
            case BizDirStatus.error:
              return ErrorView(
                message: state.errorMessage ?? 'Could not load businesses',
                onRetry: () => context.read<BusinessDirectoryCubit>().load(),
              );
            case BizDirStatus.gated:
              return const EmptyView(
                title: 'Business directory coming soon',
                subtitle:
                    'A searchable directory of verified businesses arrives once '
                    'the backend is ready.',
                icon: Icons.storefront_outlined,
              );
            case BizDirStatus.empty:
              return const EmptyView(
                title: 'No businesses found',
                subtitle: 'Try a different product, tag or city.',
                icon: Icons.storefront_outlined,
              );
            case BizDirStatus.loaded:
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: state.businesses.length,
                itemBuilder: (context, i) =>
                    _BusinessCard(business: state.businesses[i]),
              );
          }
        },
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.business});
  final Business business;

  Future<void> _boost(BuildContext context) async {
    final result = await context.read<BusinessDirectoryCubit>().boost(business);
    if (!context.mounted) return;
    AppOverlays.snack(
        context,
        result is Success
            ? 'Business boosted 🚀'
            : 'Could not boost — check your credits');
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: nex.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                  name: business.businessName ?? business.name,
                  imageUrl: MediaUrl.resolve(business.logoUrl),
                  size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                              business.businessName ?? business.name,
                              style: texts.titleMedium,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (business.isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified,
                              size: 15,
                              color: Theme.of(context).colorScheme.primary),
                        ],
                      ],
                    ),
                    if (business.location.isNotEmpty)
                      Text(business.location,
                          style: texts.bodySmall
                              ?.copyWith(color: nex.textSecondary)),
                  ],
                ),
              ),
              if (business.isPremium)
                const _Tag(label: 'Premium', icon: Icons.workspace_premium),
              if (business.isBoosted)
                const _Tag(label: 'Boosted', icon: Icons.rocket_launch),
            ],
          ),
          if ((business.description ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(business.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: nex.textSecondary)),
          ],
          if (business.products.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in business.products.take(4))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: nex.elevated,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(p, style: texts.labelSmall),
                  ),
              ],
            ),
          ],
          if (business.canBoost) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Boost listing',
              icon: Icons.rocket_launch,
              variant: AppButtonVariant.outline,
              onPressed: () => _boost(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        gradient: context.nexveero.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: Colors.white),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
