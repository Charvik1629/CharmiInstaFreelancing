import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import 'dart:math' as math;

import '../../../../core/models/user.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../broadcasts/domain/broadcast_detail.dart';
import '../../../broadcasts/presentation/cubit/create_broadcast_cubit.dart';

/// Admin · Create broadcast group (design "09 · Admin · Create broadcast
/// group"): a close + "Admin only" header, a card-based form (name +
/// description), a Members card showing the picked recipients as avatars with an
/// Add affordance (opens a searchable picker), an info note, and Cancel / Create
/// actions. Backed by `POST /broadcasts` via [CreateBroadcastCubit].
class CreateBroadcastGroupPage extends StatelessWidget {
  const CreateBroadcastGroupPage({super.key, this.editing});

  /// When provided, the page edits this existing group instead of creating one.
  final BroadcastDetail? editing;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = sl<CreateBroadcastCubit>();
        if (editing != null) cubit.initForEdit(editing!);
        return cubit;
      },
      child: _CreateBroadcastGroupView(editing: editing),
    );
  }
}

class _CreateBroadcastGroupView extends StatelessWidget {
  const _CreateBroadcastGroupView({this.editing});

  final BroadcastDetail? editing;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final isEdit = editing != null;
    return BlocListener<CreateBroadcastCubit, CreateBroadcastState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        if (state.status == CreateStatus.success) {
          AppOverlays.snack(context,
              isEdit ? 'Broadcast group updated' : 'Broadcast group created');
          context.pop<BroadcastDetail>(state.created);
        } else if (state.status == CreateStatus.failure) {
          AppOverlays.snack(
              context, state.errorMessage ?? 'Could not save broadcast group');
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                  title: isEdit ? 'Edit broadcast group' : 'New broadcast group'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: const [
                    _FormCard(),
                    SizedBox(height: AppSpacing.md),
                    _MembersCard(),
                    SizedBox(height: AppSpacing.md),
                    _InfoNote(),
                  ],
                ),
              ),
              _BottomBar(background: nex.elevated),
            ],
          ),
        ),
      ),
    );
  }
}

/// Close + title / "Admin only" header (design: no app bar).
class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: nex.border)),
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, size: 24),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: texts.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Admin only',
                    style: texts.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Name + description card. Stateful so it can pre-fill both fields when the
/// page opens in edit mode (the cubit is seeded via initForEdit).
class _FormCard extends StatefulWidget {
  const _FormCard();

  @override
  State<_FormCard> createState() => _FormCardState();
}

class _FormCardState extends State<_FormCard> {
  late final TextEditingController _name;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final state = context.read<CreateBroadcastCubit>().state;
    _name = TextEditingController(text: state.name);
    _description = TextEditingController(text: state.description);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CreateBroadcastCubit>();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _name,
            label: 'Group name',
            hint: 'Enter group name',
            textCapitalization: TextCapitalization.words,
            onChanged: cubit.setName,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _description,
            label: 'Description',
            hint: 'What is this group for?',
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: cubit.setDescription,
          ),
        ],
      ),
    );
  }
}

/// Members card: a "MEMBERS · N" header with an Add action, then the picked
/// recipients as avatars followed by a dashed "Add" circle. Both the Add link
/// and the dashed circle open the searchable member picker.
class _MembersCard extends StatelessWidget {
  const _MembersCard();

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    return BlocBuilder<CreateBroadcastCubit, CreateBroadcastState>(
      buildWhen: (p, c) => p.selected != c.selected,
      builder: (context, state) {
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('MEMBERS · ${state.selected.length}',
                      style: texts.labelSmall?.copyWith(
                          color: nex.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6)),
                  GestureDetector(
                    onTap: () => _openPicker(context),
                    child: Text('Add',
                        style: texts.labelMedium?.copyWith(
                            color: primary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final u in state.selected)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _MemberAvatar(user: u),
                      ),
                    _AddCircle(onTap: () => _openPicker(context)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPicker(BuildContext context) {
    final cubit = context.read<CreateBroadcastCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const _MemberPickerSheet(),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return SizedBox(
      width: 48,
      child: Column(
        children: [
          AppAvatar(
              name: user.name,
              imageUrl: MediaUrl.resolve(user.avatarUrl),
              size: 40),
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

/// Dashed "+" circle that opens the picker (design: trailing add affordance).
class _AddCircle extends StatelessWidget {
  const _AddCircle({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return SizedBox(
      width: 48,
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: CustomPaint(
              painter: _DashedCirclePainter(nex.iconInactive),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.add, size: 18, color: nex.iconInactive),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('Add',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: nex.textSecondary, fontSize: 9)),
        ],
      ),
    );
  }
}

/// Light-purple info note (design: tinted card with info icon).
class _InfoNote extends StatelessWidget {
  const _InfoNote();

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: nex.gradientStart.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: nex.gradientStart),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Messages send individually to each member. Only admins can '
              'create or edit these groups.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: nex.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.background});
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
        child: BlocBuilder<CreateBroadcastCubit, CreateBroadcastState>(
          buildWhen: (p, c) =>
              p.canSubmit != c.canSubmit || p.isSubmitting != c.isSubmitting,
          builder: (context, state) {
            return Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.outline,
                    onPressed: () => context.pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: 'Create group',
                    isLoading: state.isSubmitting,
                    onPressed: state.canSubmit
                        ? () => context.read<CreateBroadcastCubit>().submit()
                        : null,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Reusable surface card (design: white/elevated rounded-16 bordered cards).
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: nex.border),
      ),
      child: child,
    );
  }
}

/// The member picker (design "Create broadcast · multi-select contacts"): a
/// search field over a list of people, each row a leading checkbox + avatar +
/// name. Tapping toggles selection on the shared [CreateBroadcastCubit].
class _MemberPickerSheet extends StatelessWidget {
  const _MemberPickerSheet();

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl)),
          ),
          padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: nex.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppTextField(
                  hint: 'Search contacts',
                  prefixIcon: Icons.search,
                  onChanged: (v) =>
                      context.read<CreateBroadcastCubit>().search(v),
                ),
              ),
              Expanded(
                child: BlocBuilder<CreateBroadcastCubit, CreateBroadcastState>(
                  builder: (context, state) {
                    if (state.searching) return const LoadingView();
                    if (state.results.isEmpty) {
                      return const EmptyView(
                        title: 'Search to add members',
                        subtitle: 'Find members by name or number.',
                        icon: Icons.person_add_alt,
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: state.results.length,
                      itemBuilder: (context, i) {
                        final User u = state.results[i];
                        final selected = context
                            .read<CreateBroadcastCubit>()
                            .isSelected(u);
                        return _PickerRow(user: u, selected: selected);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A picker row: leading checkbox (gradient square + check when selected, a
/// bordered square otherwise) + avatar + name.
class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.user, required this.selected});
  final User user;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return InkWell(
      onTap: () => context.read<CreateBroadcastCubit>().toggle(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                gradient: selected ? nex.primaryGradient : null,
                color: selected ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: selected ? null : Border.all(color: nex.border, width: 1.5),
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

/// Paints a dashed ring for the "Add member" affordance (design: dashed circle).
class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    const dash = 0.5; // radians drawn
    const gap = 0.35; // radians skipped
    for (double a = 0; a < 2 * math.pi; a += dash + gap) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        a,
        dash,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
