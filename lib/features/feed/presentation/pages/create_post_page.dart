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
  const CreatePostPage({super.key, this.editLoad});

  /// When set, the composer edits this post (PUT /loads/{id}) instead of
  /// creating a new one.
  final Load? editLoad;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = sl<CreatePostCubit>()..loadCategories();
        if (editLoad != null) cubit.seedForEdit(editLoad!);
        return cubit;
      },
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: AppSpacing.xs),
            child: Text('ADD PHOTO',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: sheetCtx.nexveero.textSecondary)),
          ),
          _AttachOption(
            icon: Icons.photo_library_outlined,
            title: 'Photo',
            subtitle: 'Share images from gallery',
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _pickFromGallery();
            },
          ),
          Divider(height: 1, color: sheetCtx.nexveero.border),
          _AttachOption(
            icon: Icons.photo_camera_outlined,
            title: 'Camera',
            subtitle: 'Take a new photo',
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
    // No permission gate: image_picker uses the Android Photo Picker / iOS
    // picker, which grants access to the chosen items without a runtime
    // permission. Gating it behind READ_MEDIA_IMAGES silently blocked "Add".
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
          title: Text(
              context.select((CreatePostCubit c) => c.state.editing)
                  ? 'Edit post'
                  : 'New post'),
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
          p.canSubmit != c.canSubmit ||
          p.isSubmitting != c.isSubmitting ||
          p.editing != c.editing,
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
            child: Text(state.editing ? 'Save' : 'Publish',
                style: const TextStyle(fontWeight: FontWeight.w700)),
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
        // Design: a 3-column grid of square tiles (repeat(3,1fr), 8px gap); the
        // "Add" tile is simply the next cell. Long-press a thumbnail to reorder.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < paths.length; i++)
                  DragTarget<int>(
                    key: ValueKey(paths[i]),
                    onWillAcceptWithDetails: (d) => d.data != i,
                    onAcceptWithDetails: (d) => cubit.reorderImages(d.data, i),
                    builder: (context, candidate, rejected) =>
                        LongPressDraggable<int>(
                      data: i,
                      feedback: _Thumb(
                          path: paths[i], index: i, onRemove: () {}, size: 96),
                      childWhenDragging: _ThumbPlaceholder(
                          highlighted: candidate.isNotEmpty),
                      child: _Thumb(
                        path: paths[i],
                        index: i,
                        onRemove: () => cubit.removeImageAt(i),
                      ),
                    ),
                  ),
                if (paths.length < CreatePostCubit.maxImages)
                  _AddTile(onTap: onAdd),
              ],
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
          ],
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb(
      {required this.path,
      required this.index,
      required this.onRemove,
      this.size});

  final String path;
  final int index;
  final VoidCallback onRemove;

  /// When set, renders at a fixed square size (for the drag feedback, which sits
  /// outside the grid's layout). Null = fill the grid cell.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final tile = Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.file(File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Container(color: context.nexveero.elevated)),
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
    );
    if (size == null) return tile;
    // Drag feedback: fixed size + a Material ancestor for the badge's Text.
    return Material(
      color: Colors.transparent,
      child: SizedBox(width: size, height: size, child: tile),
    );
  }
}

/// The empty slot shown while a thumbnail is being dragged (keeps the grid cell
/// and highlights when a drop is hovering).
class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder({required this.highlighted});
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.nexveero.elevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: highlighted
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
            : null,
      ),
    );
  }
}

/// A row in the "ADD PHOTO"/attach sheet (design: 40×40 tinted icon tile with a
/// title + subtitle).
class _AttachOption extends StatelessWidget {
  const _AttachOption(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 22, color: primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: context.nexveero.textSecondary)),
                ],
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

/// A square dashed-border tile (design: the "Add" placeholder). Fills whatever
/// square cell the grid gives it.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
          color: context.nexveero.border, radius: AppRadius.md),
      child: SizedBox.expand(child: Center(child: child)),
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
              // Single content field (maps to the post title). Caption removed.
              TextField(
                onChanged: cubit.setTitle,
                maxLength: 255,
                minLines: 2,
                maxLines: 6,
                style: Theme.of(context).textTheme.titleMedium,
                // The card is the field's surface — strip the theme fill + focus
                // border so focusing doesn't draw a box inside the card.
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  counterText: '',
                  hintText: 'Write something…',
                  errorText: state.fieldErrors['title'],
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
