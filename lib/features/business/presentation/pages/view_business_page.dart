import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// "View Business" tab (design). A directory of business profiles searchable by
/// products and tags. The backend for this does not exist yet (see
/// BACKEND_REQUIREMENTS C1 — `GET /businesses`), so the tab shows a disabled
/// search field and a "coming soon" state until that endpoint lands.
class ViewBusinessPage extends StatelessWidget {
  const ViewBusinessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return Scaffold(
      appBar: AppBar(title: const Text('Businesses')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AbsorbPointer(
              child: Opacity(
                opacity: 0.6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: nex.elevated,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 20, color: nex.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Search businesses, products, tags',
                          style: TextStyle(color: nex.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Expanded(
            child: EmptyView(
              title: 'Coming soon',
              subtitle:
                  'A searchable directory of verified businesses — with products, '
                  'tags and short videos — arrives once the backend is ready.',
              icon: Icons.storefront_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
