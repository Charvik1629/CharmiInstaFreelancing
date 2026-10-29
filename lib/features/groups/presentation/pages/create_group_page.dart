import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/create_group_cubit.dart';

/// "New group": name it, (optionally) search and add members, create.
class CreateGroupPage extends StatelessWidget {
  const CreateGroupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CreateGroupCubit>(),
      child: const _CreateGroupView(),
    );
  }
}

class _CreateGroupView extends StatefulWidget {
  const _CreateGroupView();

  @override
  State<_CreateGroupView> createState() => _CreateGroupViewState();
}

class _CreateGroupViewState extends State<_CreateGroupView> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300),
        () => context.read<CreateGroupCubit>().search(q));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreateGroupCubit, CreateGroupState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        if (state.status == CreateStatus.success && state.created != null) {
          context.pop(state.created);
        } else if (state.status == CreateStatus.failure) {
          AppOverlays.snack(
              context, state.errorMessage ?? 'Could not create group');
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('New group')),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (v) =>
                        context.read<CreateGroupCubit>().setName(v),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Group name',
                      hintText: 'e.g. Surat Textile Traders',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    onChanged: (v) =>
                        context.read<CreateGroupCubit>().setDescription(v),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Selected members as removable chips.
                  BlocBuilder<CreateGroupCubit, CreateGroupState>(
                    buildWhen: (p, c) => p.selected != c.selected,
                    builder: (context, state) {
                      if (state.selected.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final u in state.selected)
                              InputChip(
                                avatar: AppAvatar(
                                    name: u.name,
                                    imageUrl: MediaUrl.resolve(u.avatarUrl),
                                    size: 24),
                                label: Text(u.name),
                                onDeleted: () =>
                                    context.read<CreateGroupCubit>().toggle(u),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearch,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Add members…',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  BlocBuilder<CreateGroupCubit, CreateGroupState>(
                    buildWhen: (p, c) =>
                        p.results != c.results ||
                        p.searching != c.searching ||
                        p.selected != c.selected,
                    builder: (context, state) {
                      if (state.searching) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))),
                        );
                      }
                      return Column(
                        children: [
                          for (final u in state.results)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: context
                                  .read<CreateGroupCubit>()
                                  .isSelected(u),
                              onChanged: (_) =>
                                  context.read<CreateGroupCubit>().toggle(u),
                              secondary: AppAvatar(
                                  name: u.name,
                                  imageUrl: MediaUrl.resolve(u.avatarUrl),
                                  size: 40),
                              title: Text(u.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: u.username != null
                                  ? Text('@${u.username}')
                                  : null,
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            _CreateBar(),
          ],
        ),
      ),
    );
  }
}

class _CreateBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: BlocBuilder<CreateGroupCubit, CreateGroupState>(
          buildWhen: (p, c) =>
              p.canSubmit != c.canSubmit || p.isSubmitting != c.isSubmitting,
          builder: (context, state) {
            return AppButton(
              label: 'Create group',
              icon: Icons.group_add_outlined,
              isLoading: state.isSubmitting,
              onPressed: state.canSubmit
                  ? () => context.read<CreateGroupCubit>().submit()
                  : null,
            );
          },
        ),
      ),
    );
  }
}
