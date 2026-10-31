import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/load.dart';
import '../../../../core/models/user.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../chat/presentation/utils/chat_start_helper.dart';
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
        appBar: AppBar(
          title: Text(initialName ?? 'Profile'),
          actions: [
            BlocBuilder<UserProfileCubit, UserProfileState>(
              builder: (context, state) {
                final user = state.user;
                if (user == null) return const SizedBox.shrink();
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    switch (value) {
                      case 'share':
                        _shareProfile(context, user);
                      case 'copy':
                        _copyLink(context, user);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'share', child: Text('Share profile')),
                    PopupMenuItem(value: 'copy', child: Text('Copy link')),
                  ],
                );
              },
            ),
          ],
        ),
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
                return RefreshIndicator(
                  onRefresh: () => context.read<UserProfileCubit>().load(),
                  child: _Body(state: state),
                );
            }
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});
  final UserProfileState state;

  @override
  Widget build(BuildContext context) {
    final user = state.user!;
    final texts = Theme.of(context).textTheme;
    final nex = context.nexveero;
    final primary = Theme.of(context).colorScheme.primary;
    // GET /users/{id} returns only name/username/verified/premium/bio/posts —
    // no roles/business/offers — so we deliberately show none of those here.
    final handle = (user.username ?? '').trim().isNotEmpty
        ? '@${user.username!.trim()}'
        : null;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Center(
          child: Column(
            children: [
              AppAvatar(
                name: user.name,
                imageUrl: MediaUrl.resolve(user.avatarUrl),
                size: 92,
                ring: user.isVerified,
                enlargeOnTap: true,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: Text(user.name, style: texts.titleLarge)),
                  if (user.isVerified) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(Icons.verified, size: 20, color: primary),
                  ],
                  if (user.isPremium) ...[
                    const SizedBox(width: 2),
                    Icon(Icons.workspace_premium, size: 20, color: nex.warning),
                  ],
                ],
              ),
              if (handle != null) ...[
                const SizedBox(height: 2),
                Text(handle,
                    style: texts.bodyMedium
                        ?.copyWith(color: nex.textSecondary)),
              ],
              if ((user.bio ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(user.bio!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: nex.elevated,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    Text('${user.postsCount}', style: texts.titleMedium),
                    const SizedBox(height: 2),
                    Text('Posts',
                        style: texts.labelSmall
                            ?.copyWith(color: nex.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // No Follow — the backend has no follow/unfollow API. Chat + Share only.
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Chat',
                icon: Icons.chat_bubble_outline,
                onPressed: () => _startChat(context, user),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton(
              label: 'Share',
              icon: Icons.ios_share,
              variant: AppButtonVariant.outline,
              expanded: false,
              onPressed: () => _shareProfile(context, user),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _PostsGrid(
          posts: state.posts,
          postsStatus: state.postsStatus,
          postsCount: user.postsCount,
        ),
      ],
    );
  }

  /// Opens (or reopens) a 1:1 chat with this user via `POST /chats`. If the peer
  /// has Set-PIN on, prompts for their 4-digit PIN first, then opens the thread.
  Future<void> _startChat(BuildContext context, User user) async {
    await startChatWithPinCheck(
      context,
      userId: user.id,
      name: user.name,
      avatarUrl: user.avatarUrl,
    );
  }
}

/// The posts section of another user's profile. The backend has no "posts by
/// user" endpoint, so [UserProfileCubit] gathers the user's posts from the feed
/// (filtering by author id) and passes them here. Each tile shows the post's
/// cover and opens its detail on tap; posts without an image show a text tile.
class _PostsGrid extends StatelessWidget {
  const _PostsGrid({
    required this.posts,
    required this.postsStatus,
    required this.postsCount,
  });

  final List<Load> posts;
  final PostsStatus postsStatus;
  final int postsCount;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.grid_on, size: 18, color: nex.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text('Posts', style: texts.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildBody(context, nex, texts),
      ],
    );
  }

  Widget _buildBody(BuildContext context, NexveeroColors nex, TextTheme texts) {
    // Still scanning the feed for this user's posts: show placeholder tiles
    // sized to the known count so the section doesn't jump.
    if (postsStatus == PostsStatus.loading ||
        postsStatus == PostsStatus.initial) {
      final tiles = postsCount.clamp(1, 9);
      return _grid([
        for (var i = 0; i < tiles; i++)
          DecoratedBox(
            decoration: BoxDecoration(
              color: nex.elevated,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
      ]);
    }

    if (posts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        decoration: BoxDecoration(
          color: nex.elevated,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            Icon(Icons.photo_library_outlined,
                size: 32, color: nex.iconInactive),
            const SizedBox(height: AppSpacing.sm),
            Text('No posts yet',
                style: texts.bodyMedium?.copyWith(color: nex.textSecondary)),
          ],
        ),
      );
    }

    return _grid([for (final load in posts) _PostTile(load: load)]);
  }

  Widget _grid(List<Widget> children) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        children: children,
      );
}

/// A single post tile in the profile grid: the post's cover image (first of its
/// carousel, else the legacy cover) or a text fallback, tappable to its detail.
class _PostTile extends StatelessWidget {
  const _PostTile({required this.load});
  final Load load;

  String? get _coverUrl {
    if (load.imageMedia.isNotEmpty) return load.imageMedia.first.url;
    if (load.hasImage) return load.mediaUrl;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final cover = _coverUrl;
    return GestureDetector(
      onTap: () => context.push(AppRoutes.postDetail, extra: load),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: cover != null
            ? Image.network(
                MediaUrl.resolve(cover) ?? cover,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _textTile(context, nex),
              )
            : _textTile(context, nex),
      ),
    );
  }

  Widget _textTile(BuildContext context, NexveeroColors nex) => Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        color: nex.elevated,
        alignment: Alignment.center,
        child: Text(
          load.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: nex.textSecondary),
        ),
      );
}

/// A shareable link to this user's profile (server `share_url`, else derived).
String? _profileLink(User user) =>
    user.shareUrl ??
    (user.username != null ? 'https://nexveero.com/u/${user.username}' : null);

Future<void> _shareProfile(BuildContext context, User user) async {
  final link = _profileLink(user);
  if (link == null) {
    AppOverlays.snack(context, 'No profile link available yet.');
    return;
  }
  await SharePlus.instance.share(
    ShareParams(text: '${user.name} on Nexveero\n$link'),
  );
}

Future<void> _copyLink(BuildContext context, User user) async {
  final link = _profileLink(user);
  if (link == null) {
    AppOverlays.snack(context, 'No profile link available yet.');
    return;
  }
  await Clipboard.setData(ClipboardData(text: link));
  if (context.mounted) AppOverlays.snack(context, 'Link copied');
}
