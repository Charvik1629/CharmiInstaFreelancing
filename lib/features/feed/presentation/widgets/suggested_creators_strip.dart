import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// "Suggested creators" carousel from the design's Home Feed. There is no
/// suggestions/follow API yet (see MISSING_APIS #4), so this renders as a gated
/// preview: real placeholder cards with a disabled Follow and a "Coming soon"
/// tag, rather than fabricated people. Swap the placeholder list for the API
/// response and enable Follow once the endpoints exist.
class SuggestedCreatorsStrip extends StatelessWidget {
  const SuggestedCreatorsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                Text('Suggested creators', style: texts.titleSmall),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.nexveero.elevated,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text('Coming soon',
                      style: texts.labelSmall?.copyWith(color: context.nexveero.textSecondary)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 188,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, _) => const _CreatorCardPlaceholder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorCardPlaceholder extends StatelessWidget {
  const _CreatorCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w) => Container(
          width: w,
          height: 9,
          decoration: BoxDecoration(
            color: context.nexveero.border,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        );
    return Container(
      width: 132,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.nexveero.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppAvatar(name: '', size: 52),
          const SizedBox(height: AppSpacing.sm),
          bar(64),
          const SizedBox(height: 6),
          bar(40),
          const SizedBox(height: AppSpacing.md),
          // Disabled until the follow API exists.
          const AppButton(
            label: 'Follow',
            variant: AppButtonVariant.tonal,
            onPressed: null,
          ),
        ],
      ),
    );
  }
}
