import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// A single shimmering placeholder block (design "Loading Skeletons").
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final base = nex.elevated;
    final highlight = nex.border;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * _c.value, 0),
              end: Alignment(1 - 2 * _c.value, 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// A feed of skeleton post cards for the loading state.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: count,
      itemBuilder: (_, _) => Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.nexveero.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonBox(width: 40, height: 40, shape: BoxShape.circle),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 120, height: 12),
                    SizedBox(height: 6),
                    SkeletonBox(width: 80, height: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const SkeletonBox(width: double.infinity, height: 160, radius: 12),
            const SizedBox(height: AppSpacing.md),
            const SkeletonBox(width: double.infinity, height: 12),
            const SizedBox(height: 6),
            const SkeletonBox(width: 200, height: 12),
          ],
        ),
      ),
    );
  }
}

/// A list of skeleton rows (chats, notifications, etc.).
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 8});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: count,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Row(
          children: [
            const SkeletonBox(width: 48, height: 48, shape: BoxShape.circle),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 140, height: 12),
                  SizedBox(height: 8),
                  SkeletonBox(width: double.infinity, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
