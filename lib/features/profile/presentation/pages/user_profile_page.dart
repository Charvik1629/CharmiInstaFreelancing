import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/user.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../chat/domain/repositories/chat_repository.dart';
import '../cubit/user_profile_cubit.dart';

/// Another user's profile (design "Creator Profile · other user"). Read-only
/// header + a Message action that opens (or reopens) a 1:1 chat via
/// `POST /chats`. No Follow — the backend has no follow/unfollow API.
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
        // Follow removed — no follow/unfollow API. Message is the only action.
        AppButton(
          label: 'Message',
          icon: Icons.chat_bubble_outline,
          onPressed: () => _startChat(context, user),
        ),
      ],
    );
  }

  /// Opens (or reopens) a 1:1 chat with this user via `POST /chats`. If the peer
  /// has Set-PIN on, prompts for their 4-digit PIN first, then opens the thread.
  Future<void> _startChat(BuildContext context, User user) async {
    final repo = sl<ChatRepository>();
    final pinReq = await AppLoader.run(repo.chatPinRequired(user.id));
    if (!context.mounted) return;

    String? pin;
    if (pinReq.valueOrNull == true) {
      pin = await context.push<String>(
        AppRoutes.enterPin,
        extra: {'name': user.name, 'avatar': user.avatarUrl},
      );
      if (pin == null) return; // cancelled
    }

    final result = await AppLoader.run(repo.startChat(user.id, pin: pin));
    if (!context.mounted) return;
    switch (result) {
      case Success(value: final conversation):
        context.push(AppRoutes.chatThread, extra: conversation);
      case Err(failure: final f):
        AppOverlays.snack(context, f.message);
    }
  }
}
