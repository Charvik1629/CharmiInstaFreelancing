import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/wallet_package.dart';
import '../cubit/admin_packages_cubit.dart';
import 'package_form_sheet.dart';

/// Admin · Packages (design). Manage purchasable credit packages backed by
/// `/admin/wallet/packages`: create, edit, activate/deactivate, delete.
class AdminPackagesPage extends StatelessWidget {
  const AdminPackagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AdminPackagesCubit>()..load(),
      child: const _PackagesView(),
    );
  }
}

class _PackagesView extends StatelessWidget {
  const _PackagesView();

  static Future<void> openForm(BuildContext context, {WalletPackage? package}) {
    final cubit = context.read<AdminPackagesCubit>();
    return AppOverlays.sheet<void>(
      context,
      builder: (_) => PackageFormSheet(cubit: cubit, package: package),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Packages'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New package',
              onPressed: () => openForm(context),
            ),
          ),
        ],
      ),
      body: BlocConsumer<AdminPackagesCubit, AdminPackagesState>(
        listenWhen: (p, c) =>
            p.errorMessage != c.errorMessage && c.errorMessage != null,
        listener: (context, state) =>
            AppOverlays.snack(context, state.errorMessage!),
        builder: (context, state) {
          switch (state.status) {
            case PackagesStatus.initial:
            case PackagesStatus.loading:
              return const LoadingView();
            case PackagesStatus.error:
              return ErrorView(
                message: state.errorMessage ?? 'Could not load packages',
                onRetry: () => context.read<AdminPackagesCubit>().load(),
              );
            case PackagesStatus.empty:
              return const EmptyView(
                title: 'No packages',
                subtitle: 'Create one so users can buy credits.',
                icon: Icons.inventory_2_outlined,
              );
            case PackagesStatus.loaded:
              return RefreshIndicator(
                onRefresh: () => context.read<AdminPackagesCubit>().refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: state.packages.length,
                  itemBuilder: (context, i) =>
                      _PackageCard(package: state.packages[i]),
                ),
              );
          }
        },
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package});
  final WalletPackage package;

  Future<void> _delete(BuildContext context) async {
    final ok = await AppOverlays.confirm(
      context,
      title: 'Delete package?',
      message: '"${package.name}" will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done =
        await context.read<AdminPackagesCubit>().deletePackage(package.id);
    if (context.mounted && done) AppOverlays.snack(context, 'Package deleted');
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
              Expanded(child: Text(package.name, style: texts.titleMedium)),
              if (package.isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: nex.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text('Active',
                      style: TextStyle(color: nex.success, fontSize: 11)),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          const SizedBox(height: 2),
          Text(
            '${package.credits} credits · ₹${package.amount.toStringAsFixed(0)} · order ${package.sortOrder}',
            style: TextStyle(color: nex.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: () =>
                    _PackagesView.openForm(context, package: package),
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
