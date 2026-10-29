import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/user.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../../../wallet/presentation/widgets/overage_dialog.dart';
import '../../domain/broadcast_detail.dart';
import '../cubit/create_broadcast_cubit.dart';

/// New broadcast (design "Create Broadcast · name · multi-select contacts"):
/// a close + "New broadcast" header, the list name, the picked recipients as
/// avatars (each removable), a contact search over a checkbox list, and a
/// "Create broadcast" action.
class CreateBroadcastPage extends StatelessWidget {
  const CreateBroadcastPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CreateBroadcastCubit>(),
      child: const _CreateBroadcastView(),
    );
  }
}

class _CreateBroadcastView extends StatelessWidget {
  const _CreateBroadcastView();

  /// Broadcast list overage (design "User · Chat list overage"): the free-list
  /// limit is reached, so offer to debit credits or subscribe.
  Future<void> _showOverage(BuildContext context) async {
    final wallet = (await sl<WalletRepository>().getWallet()).valueOrNull;
    if (!context.mounted) return;
    final cost = wallet?.broadcastCost ?? 15;
    final balance = wallet?.creditBalance ?? 0;
    final choice = await OverageDialog.show(
      context,
      cost: cost,
      balance: balance,
      title: balance >= cost
          ? 'Free list limit reached'
          : 'Broadcast list limit over',
      message: balance >= cost
          ? 'Creating another broadcast list will debit $cost credits from your wallet.'
          : 'Your free broadcast lists are used up. Subscribe to keep creating.',
    );
    if (!context.mounted) return;
    if (choice == OverageChoice.subscribe) {
      context.push(AppRoutes.subscription);
    } else if (choice == OverageChoice.debit) {
      context.read<CreateBroadcastCubit>().submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreateBroadcastCubit, CreateBroadcastState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        if (state.status == CreateStatus.success) {
          context.pop<BroadcastDetail>(state.created);
        } else if (state.status == CreateStatus.failure) {
          if (state.insufficientCredits) {
            _showOverage(context);
          } else {
            AppOverlays.snack(
                context, state.errorMessage ?? 'Could not create broadcast');
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: const [
              _Header(),
              _NameField(),
              _SelectedRow(),
              _SearchField(),
              Expanded(child: _Results()),
            ],
          ),
        ),
        bottomNavigationBar: const _CreateBar(),
      ),
    );
  }
}

/// Close + "New broadcast" + "Create" header (design: no app bar).
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: nex.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 24),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text('New broadcast',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const _CreateAction(),
        ],
      ),
    );
  }
}

class _CreateAction extends StatelessWidget {
  const _CreateAction();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateBroadcastCubit, CreateBroadcastState>(
      buildWhen: (p, c) =>
          p.canSubmit != c.canSubmit || p.isSubmitting != c.isSubmitting,
      builder: (context, state) {
        if (state.isSubmitting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return TextButton(
          onPressed: state.canSubmit
              ? () => context.read<CreateBroadcastCubit>().submit()
              : null,
          child: const Text('Create'),
        );
      },
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: AppTextField(
        label: 'Broadcast name',
        hint: 'Enter list name',
        prefixIcon: Icons.campaign_outlined,
        onChanged: (v) => context.read<CreateBroadcastCubit>().setName(v),
      ),
    );
  }
}

/// Selected recipients as avatars (design: "Selected · N contacts" with a
/// cancel badge to remove each).
class _SelectedRow extends StatelessWidget {
  const _SelectedRow();

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return BlocBuilder<CreateBroadcastCubit, CreateBroadcastState>(
      buildWhen: (p, c) => p.selected != c.selected,
      builder: (context, state) {
        if (state.selected.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selected · ${state.selected.length} contacts',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: nex.textSecondary, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 66,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final u in state.selected)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _SelectedAvatar(user: u),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SelectedAvatar extends StatelessWidget {
  const _SelectedAvatar({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      width: 50,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => context.read<CreateBroadcastCubit>().toggle(user),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AppAvatar(
                    name: user.name,
                    imageUrl: MediaUrl.resolve(user.avatarUrl),
                    size: 44),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cancel,
                        size: 18, color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(user.name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: nex.textSecondary, fontSize: 9)),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      child: AppTextField(
        hint: 'Search contacts',
        prefixIcon: Icons.search,
        onChanged: (v) => context.read<CreateBroadcastCubit>().search(v),
      ),
    );
  }
}

/// Contact list with a leading checkbox (design: checkbox + avatar + name).
class _Results extends StatelessWidget {
  const _Results();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateBroadcastCubit, CreateBroadcastState>(
      builder: (context, state) {
        if (state.searching) return const LoadingView();
        if (state.results.isEmpty) {
          return const EmptyView(
            title: 'Search to add people',
            subtitle: 'Find recipients by name or number.',
            icon: Icons.person_add_alt,
          );
        }
        return ListView.builder(
          itemCount: state.results.length,
          itemBuilder: (context, i) {
            final User u = state.results[i];
            final selected = context.read<CreateBroadcastCubit>().isSelected(u);
            return _ContactRow(user: u, selected: selected);
          },
        );
      },
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.user, required this.selected});
  final User user;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return InkWell(
      onTap: () => context.read<CreateBroadcastCubit>().toggle(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                gradient: selected ? nex.primaryGradient : null,
                borderRadius: BorderRadius.circular(6),
                border:
                    selected ? null : Border.all(color: nex.border, width: 1.5),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            AppAvatar(
                name: user.name,
                imageUrl: MediaUrl.resolve(user.avatarUrl),
                size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(user.name,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom "Create broadcast" gradient button (design: prominent CTA).
class _CreateBar extends StatelessWidget {
  const _CreateBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.nexveero.elevated,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
        child: BlocBuilder<CreateBroadcastCubit, CreateBroadcastState>(
          buildWhen: (p, c) =>
              p.canSubmit != c.canSubmit || p.isSubmitting != c.isSubmitting,
          builder: (context, state) {
            return AppButton(
              label: 'Create broadcast',
              isLoading: state.isSubmitting,
              onPressed: state.canSubmit
                  ? () => context.read<CreateBroadcastCubit>().submit()
                  : null,
            );
          },
        ),
      ),
    );
  }
}
