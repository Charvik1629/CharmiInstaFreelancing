import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/tag.dart';
import '../cubit/admin_tags_cubit.dart';
import 'tag_form_sheet.dart';

/// Admin · Tags (design). Manage the tag catalogue used for posts / business
/// profiles: create, edit, activate/deactivate, delete.
class AdminTagsPage extends StatelessWidget {
  const AdminTagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AdminTagsCubit>()..load(),
      child: const _TagsView(),
    );
  }
}

class _TagsView extends StatelessWidget {
  const _TagsView();

  static Future<void> _openForm(BuildContext context, {Tag? tag}) {
    final cubit = context.read<AdminTagsCubit>();
    return AppOverlays.sheet<void>(
      context,
      builder: (_) => TagFormSheet(cubit: cubit, tag: tag),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add tag',
              onPressed: () => _openForm(context),
            ),
          ),
        ],
      ),
      body: BlocConsumer<AdminTagsCubit, AdminTagsState>(
        listenWhen: (p, c) =>
            p.errorMessage != c.errorMessage && c.errorMessage != null,
        listener: (context, state) =>
            AppOverlays.snack(context, state.errorMessage!),
        builder: (context, state) {
          switch (state.status) {
            case TagsStatus.initial:
            case TagsStatus.loading:
              return const LoadingView();
            case TagsStatus.error:
              return ErrorView(
                message: state.errorMessage ?? 'Could not load tags',
                onRetry: () => context.read<AdminTagsCubit>().load(),
              );
            case TagsStatus.empty:
              return EmptyView(
                title: 'No tags yet',
                subtitle: 'Add a tag so users can categorise posts.',
                icon: Icons.sell_outlined,
              );
            case TagsStatus.loaded:
              return RefreshIndicator(
                onRefresh: () => context.read<AdminTagsCubit>().refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: state.tags.length,
                  itemBuilder: (context, i) => _TagRow(tag: state.tags[i]),
                ),
              );
          }
        },
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tag});
  final Tag tag;

  Future<void> _delete(BuildContext context) async {
    final ok = await AppOverlays.confirm(
      context,
      title: 'Delete tag?',
      message: '"${tag.name}" will be removed from the catalogue.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await context.read<AdminTagsCubit>().deleteTag(tag.id);
    if (context.mounted && done) AppOverlays.snack(context, 'Tag deleted');
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: nex.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(tag.name,
                          style: texts.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (!tag.isActive) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: nex.elevated,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text('Inactive',
                            style: texts.labelSmall
                                ?.copyWith(color: nex.textSecondary)),
                      ),
                    ],
                  ],
                ),
                if (tag.slug.isNotEmpty)
                  Text('${tag.slug} · order ${tag.sortOrder}',
                      style: texts.labelSmall
                          ?.copyWith(color: nex.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit',
            onPressed: () => _TagsView._openForm(context, tag: tag),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Delete',
            color: Theme.of(context).colorScheme.error,
            onPressed: () => _delete(context),
          ),
        ],
      ),
    );
  }
}
