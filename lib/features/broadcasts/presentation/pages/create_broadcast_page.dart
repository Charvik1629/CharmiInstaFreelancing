import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/user.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/broadcast_detail.dart';
import '../cubit/create_broadcast_cubit.dart';

/// New broadcast (design): name the list, search + pick recipients, create.
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreateBroadcastCubit, CreateBroadcastState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        if (state.status == CreateStatus.success) {
          context.pop<BroadcastDetail>(state.created);
        } else if (state.status == CreateStatus.failure) {
          AppOverlays.snack(context, state.errorMessage ?? 'Could not create broadcast');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New broadcast'),
          actions: const [_CreateAction()],
        ),
        body: Column(
          children: [
            const _NameField(),
            const _SelectedChips(),
            const _SearchField(),
            const Expanded(child: _Results()),
          ],
        ),
      ),
    );
  }
}

class _CreateAction extends StatelessWidget {
  const _CreateAction();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateBroadcastCubit, CreateBroadcastState>(
      buildWhen: (p, c) => p.canSubmit != c.canSubmit || p.isSubmitting != c.isSubmitting,
      builder: (context, state) {
        if (state.isSubmitting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Center(
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        return TextButton(
          onPressed: state.canSubmit ? () => context.read<CreateBroadcastCubit>().submit() : null,
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: AppTextField(
        label: 'Broadcast name',
        hint: 'e.g. Client Updates',
        prefixIcon: Icons.campaign_outlined,
        onChanged: (v) => context.read<CreateBroadcastCubit>().setName(v),
      ),
    );
  }
}

class _SelectedChips extends StatelessWidget {
  const _SelectedChips();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateBroadcastCubit, CreateBroadcastState>(
      buildWhen: (p, c) => p.selected != c.selected,
      builder: (context, state) {
        if (state.selected.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selected · ${state.selected.length} contacts',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.nexveero.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final u in state.selected)
                      Chip(
                        label: Text(u.name),
                        onDeleted: () => context.read<CreateBroadcastCubit>().toggle(u),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppTextField(
        label: 'Add recipients',
        hint: 'Search people',
        prefixIcon: Icons.search,
        onChanged: (v) => context.read<CreateBroadcastCubit>().search(v),
      ),
    );
  }
}

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
            return ListTile(
              leading: AppAvatar(
                  name: u.name, imageUrl: MediaUrl.resolve(u.avatarUrl), size: 40),
              title: Text(u.name),
              trailing: Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? Theme.of(context).colorScheme.primary : context.nexveero.iconInactive,
              ),
              onTap: () => context.read<CreateBroadcastCubit>().toggle(u),
            );
          },
        );
      },
    );
  }
}
