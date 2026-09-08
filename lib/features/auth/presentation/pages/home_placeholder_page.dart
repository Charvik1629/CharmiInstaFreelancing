import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../cubit/auth_cubit.dart';

/// Temporary authenticated landing screen. Confirms the session works end to
/// end; replaced by the real Feed in Module 5.
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.state.user);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nexveero'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Signed in', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(user?.name ?? '—',
                style: Theme.of(context).textTheme.titleMedium),
            if (user?.email != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(user!.email!),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('Feed arrives in Module 5',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
