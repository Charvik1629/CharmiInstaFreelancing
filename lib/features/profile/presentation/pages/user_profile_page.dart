import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/user.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/user_profile_cubit.dart';

/// Another user's profile (design "Creator Profile · other user"). Read-only
/// header + a Message action. Following is gated (no follow API — MISSING_APIS
/// #4); starting a chat from here awaits chat-start wiring.
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key, required this.userId, this.initialName});

  final int userId;
  final String? initialName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<UserProfileCubit>(param1: userId)..load(),
      child: Scaffold(
        appBar: AppBar(title: Text(initialName ?? 'Profile')),
        body: BlocBuilder<UserProfileCubit, UserProfileState>(
          builder: (context, state) {
            switch (state.status) {
              case UserProfileStatus.loading:
              case UserProfileStatus.initial:
                return const LoadingView();
              case UserProfileStatus.error:
                return ErrorView(
                  message: state.errorMessage ?? 'Could not load profile',
                  onRetry: () => context.read<UserProfileCubit>().load(),
                );
              case UserProfileStatus.loaded:
                return _Body(user: state.user!);
            }
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final role = user.isAdmin ? 'Admin' : (user.isCreator ? 'Creator' : 'Member');
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Center(
          child: Column(
            children: [
              AppAvatar(
                name: user.name,
                imageUrl: MediaUrl.resolve(user.avatarUrl),
                size: 92,
                ring: user.canPost,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: Text(user.name, style: texts.titleLarge)),
                  if (user.canPost) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(Icons.verified,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(role,
                  style: texts.bodyMedium?.copyWith(color: context.nexveero.textSecondary)),
              if ((user.bio ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(user.bio!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Message',
                icon: Icons.chat_bubble_outline,
                onPressed: () => AppOverlays.snack(context,
                    'Starting a chat from a profile arrives with chat-start wiring.'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton(
              label: 'Follow',
              variant: AppButtonVariant.outline,
              expanded: false,
              onPressed: () => AppOverlays.snack(
                  context, 'Following needs the follow API (see MISSING_APIS #4).'),
            ),
          ],
        ),
      ],
    );
  }
}
