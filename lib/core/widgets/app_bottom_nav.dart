import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// A bottom-nav destination. [badge] shows a small dot (e.g. unread chats).
class AppNavItem {
  const AppNavItem({required this.icon, required this.label, this.badge = false});
  final IconData icon;
  final String label;
  final bool badge;
}

/// Bottom navigation matching the design: icon-only, with the active
/// destination rendered as a gradient pill and a red dot badge where needed.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nexveero = context.nexveero;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: nexveero.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                _NavButton(
                  item: items[i],
                  active: i == currentIndex,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.onTap});
  final AppNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nexveero = context.nexveero;
    final child = active
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              gradient: nexveero.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Icon(item.icon, color: Colors.white, size: 26),
          )
        : Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Icon(item.icon, color: nexveero.iconInactive, size: 26),
          );

    return Semantics(
      label: item.label,
      selected: active,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: item.badge
            ? Badge(
                smallSize: 8,
                backgroundColor: Theme.of(context).colorScheme.error,
                child: child,
              )
            : child,
      ),
    );
  }
}
