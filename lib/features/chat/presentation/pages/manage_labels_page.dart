import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/chat_label.dart';
import '../cubit/chat_labels_cubit.dart';
import 'label_form_sheet.dart';

/// Chat · Manage labels (design). Personal WhatsApp-style labels: create, edit,
/// delete. Reached from the Chats inbox app bar.
class ManageLabelsPage extends StatelessWidget {
  const ManageLabelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChatLabelsCubit>()..load(),
      child: const _ManageLabelsView(),
    );
  }
}

class _ManageLabelsView extends StatelessWidget {
  const _ManageLabelsView();

  static Future<void> openForm(BuildContext context, {ChatLabel? label}) {
    final cubit = context.read<ChatLabelsCubit>();
    return AppOverlays.sheet<void>(
      context,
      builder: (_) => LabelFormSheet(cubit: cubit, label: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Labels'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New label',
              onPressed: () => openForm(context),
            ),
          ),
        ],
      ),
      body: BlocConsumer<ChatLabelsCubit, ChatLabelsState>(
        listenWhen: (p, c) =>
            p.errorMessage != c.errorMessage && c.errorMessage != null,
        listener: (context, state) =>
            AppOverlays.snack(context, state.errorMessage!),
        builder: (context, state) {
          switch (state.status) {
            case LabelsStatus.initial:
            case LabelsStatus.loading:
              return const LoadingView();
            case LabelsStatus.error:
              return ErrorView(
                message: state.errorMessage ?? 'Could not load labels',
                onRetry: () => context.read<ChatLabelsCubit>().load(),
              );
            case LabelsStatus.empty:
              return const EmptyView(
                title: 'No labels yet',
                subtitle: 'Create labels to organise your chats.',
                icon: Icons.label_outline,
              );
            case LabelsStatus.loaded:
              return RefreshIndicator(
                onRefresh: () => context.read<ChatLabelsCubit>().refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: state.labels.length,
                  itemBuilder: (context, i) => _LabelRow(label: state.labels[i]),
                ),
              );
          }
        },
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label});
  final ChatLabel label;

  Future<void> _delete(BuildContext context) async {
    final ok = await AppOverlays.confirm(
      context,
      title: 'Delete label?',
      message: '"${label.name}" will be removed from all chats.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await context.read<ChatLabelsCubit>().deleteLabel(label.id);
    if (context.mounted && done) AppOverlays.snack(context, 'Label deleted');
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final color = label.colorValue(Theme.of(context).colorScheme.primary);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: nex.border),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(label.name,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit',
            onPressed: () => _ManageLabelsView.openForm(context, label: label),
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
