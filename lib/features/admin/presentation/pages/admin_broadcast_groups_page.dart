import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/widgets.dart';

/// Admin · Broadcast groups (design "Admin · Broadcast groups", HTML 3862).
/// Reusable recipient groups admins target with broadcasts. No backend endpoint
/// yet, so this shows the design's empty state; the create form is ready.
class AdminBroadcastGroupsPage extends StatelessWidget {
  const AdminBroadcastGroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New group',
            onPressed: () => context.push(AppRoutes.createBroadcastGroup),
          ),
        ],
      ),
      body: EmptyView(
        title: 'No broadcast groups yet',
        subtitle:
            'Create reusable recipient groups to target broadcasts. Turns on '
            'once the backend adds broadcast-group endpoints.',
        icon: Icons.groups_2_outlined,
        actionLabel: 'Create group',
        onAction: () => context.push(AppRoutes.createBroadcastGroup),
      ),
    );
  }
}
