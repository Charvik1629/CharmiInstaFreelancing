import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/load.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_flow.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../tags/domain/entities/tag.dart';
import '../cubit/create_post_cubit.dart';
import '../widgets/tag_picker_sheet.dart';

/// The composer (design "New post"). A reorderable multi-image strip, a caption
/// card, category, and Location / Tags rows. The API accepts one image + text +
/// category today, so extra images upload as just the cover and Location/Tags
/// are gated (see MISSING_APIS #6). Pops with the created [Load].
class CreatePostPage extends StatelessWidget {
  const CreatePostPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CreatePostCubit>()..loadCategories(),
      child: const _CreatePostView(),
    );
  }
}

class _CreatePostView extends StatefulWidget {
  const _CreatePostView();

  @override
  State<_CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<_CreatePostView> {
  final _picker = ImagePicker();

  void _openAddSheet() {
    AppOverlays.sheet<void>(
      context,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Photo library'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _pickFromGallery();
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _pickFromCamera();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final cubit = context.read<CreatePostCubit>();
    final outcome = await PermissionFlow.ensure(context, AppPermission.photos);
    if (!outcome.isUsable) return;
    try {
      final files = await _picker.pickMultiImage(maxWidth: 1600, imageQuality: 85);
      for (final f in files) {
        cubit.addImage(f.path);
      }
    } catch (_) {
      if (mounted) AppOverlays.snack(context, 'Could not open photos');
    }
  }

  Future<void> _pickFromCamera() async {
    final cubit = context.read<CreatePostCubit>();
    final outcome = await PermissionFlow.ensure(context, AppPermission.camera);
    if (!outcome.isUsable) return;
    try {
      final f = await _picker.pickImage(
          source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
      if (f != null) cubit.addImage(f.path);
    } catch (_) {
      if (mounted) AppOverlays.snack(context, 'Could not open camera');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreatePostCubit, CreatePostState>(
      listenWhen: (p, c) => p.submitStatus != c.submitStatus,
      listener: (context, state) {
        if (state.submitStatus == SubmitStatus.success) {
          context.pop<Load>(state.created);
        } else if (state.submitStatus == SubmitStatus.failure) {
          AppOverlays.snack(context, state.errorMessage ?? 'Could not publish post');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
          centerTitle: true,
          title: const Text('New post'),
          actions: const [_PublishAction()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _ImageStrip(onAdd: _openAddSheet),
              const SizedBox(height: AppSpacing.lg),
              const _CaptionCard(),
              const SizedBox(height: AppSpacing.lg),
              const _CategoryPicker(),
              const SizedBox(height: AppSpacing.md),
              const _MetaRows(),
            ],
          ),
        ),
      ),
    );
  }
}

/// AppBar "Publish" action — spinner while submitting, disabled until valid.
class _PublishAction extends StatelessWidget {
  const _PublishAction();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreatePostCubit, CreatePostState>(
      buildWhen: (p, c) =>
          p.canSubmit != c.canSubmit || p.isSubmitting != c.isSubmitting,
      builder: (context, state) {
        if (state.isSubmitting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Center(
              child: SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: TextButton(
            onPressed:
                state.canSubmit ? () => context.read<CreatePostCubit>().submit() : null,
            child: const Text('Publish', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        );
      },
    );
  }
}

/// The reorderable image strip + "Add" tile (design: numbered thumbnails, remove,
/// "Hold & drag to reorder").
class _ImageStrip extends StatelessWidget {
  const _ImageStrip({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreatePostCubit, CreatePostState>(
      buildWhen: (p, c) => p.imagePaths != c.imagePaths,
      builder: (context, state) {
        final cubit = context.read<CreatePostCubit>();
        final paths = state.imagePaths;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 104,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (paths.isNotEmpty)
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        onReorderItem: cubit.reorderImages,
                        itemCount: paths.length,
                        itemBuilder: (context, i) => _Thumb(
                          key: ValueKey(paths[i]),
                          path: paths[i],
                          index: i,
                          onRemove: () => cubit.removeImageAt(i),
                        ),
                      ),
                    ),
                  _AddTile(onTap: onAdd),
                ],
              ),
            ),
            if (paths.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.drag_indicator, size: 16, color: context.nexveero.textSecondary),
                  const SizedBox(width: 4),
                  Text('Hold & drag to reorder',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: context.nexveero.textSecondary)),
                ],
              ),
            ],
            if (state.hasExtraImages) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Only the first photo is uploaded for now (multi-photo posts are coming soon).',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.nexveero.warning),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb(
      {super.key, required this.path, required this.index, required this.onRemove});

  final String path;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.file(File(path),
                  width: 96, height: 96, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(width: 96, height: 96, color: context.nexveero.elevated)),
            ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text('${index + 1}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: const CircleAvatar(
                  radius: 11,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: DottedBorderBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: primary),
            const SizedBox(height: 4),
            Text('Add', style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// A 96×96 dashed-border tile (design: the "Add" placeholder).
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
          color: context.nexveero.border, radius: AppRadius.md),
      child: SizedBox(width: 96, height: 96, child: Center(child: child)),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) => old.color != color;
}

/// Title + caption in one rounded card (design: bold text line + "Add a caption…").
class _CaptionCard extends StatelessWidget {
  const _CaptionCard();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CreatePostCubit>();
    return BlocBuilder<CreatePostCubit, CreatePostState>(
      buildWhen: (p, c) =>
          p.fieldErrors['title'] != c.fieldErrors['title'] ||
          p.fieldErrors['body'] != c.fieldErrors['body'],
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.nexveero.elevated,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                onChanged: cubit.setTitle,
                maxLength: 120,
                style: Theme.of(context).textTheme.titleMedium,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  counterText: '',
                  hintText: 'Write something…',
                  errorText: state.fieldErrors['title'],
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                onChanged: cubit.setBody,
                maxLines: 4,
                minLines: 2,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Add a caption…',
                  errorText: state.fieldErrors['body'],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreatePostCubit, CreatePostState>(
      buildWhen: (p, c) =>
          p.categories != c.categories || p.selectedTypeId != c.selectedTypeId,
      builder: (context, state) {
        if (state.categories.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final type in state.categories)
                  AppChip(
                    label: type.name,
                    selected: type.id == state.selectedTypeId,
                    onTap: () => context.read<CreatePostCubit>().selectType(type.id),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Location + Add tags rows (design). Tags are wired to GET /tags; location has
/// no API yet (see BACKEND_REQUIREMENTS I2 / post location), so it stays gated.
class _MetaRows extends StatelessWidget {
  const _MetaRows();

  Future<void> _pickTags(BuildContext context) async {
    final cubit = context.read<CreatePostCubit>();
    final selected = await AppOverlays.sheet<List<Tag>>(
      context,
      builder: (_) => TagPickerSheet(initial: cubit.state.selectedTags),
    );
    if (selected != null) cubit.setTags(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetaRow(
          icon: Icons.location_on_outlined,
          label: 'Add location',
          onTap: () => AppOverlays.snack(
              context, 'Location tagging arrives with an upcoming update.'),
        ),
        Divider(height: 1, color: context.nexveero.border),
        _MetaRow(
          icon: Icons.sell_outlined,
          label: 'Add tags',
          onTap: () => _pickTags(context),
        ),
        BlocBuilder<CreatePostCubit, CreatePostState>(
          buildWhen: (p, c) => p.selectedTags != c.selectedTags,
          builder: (context, state) {
            if (state.selectedTags.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final t in state.selectedTags)
                    Chip(
                      label: Text(t.name),
                      onDeleted: () => context.read<CreatePostCubit>().setTags(
                          state.selectedTags
                              .where((x) => x.id != t.id)
                              .toList()),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: TextStyle(color: context.nexveero.textSecondary)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
