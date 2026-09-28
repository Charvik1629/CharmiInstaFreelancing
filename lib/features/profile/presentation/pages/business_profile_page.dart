import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/user.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../chat/domain/repositories/chat_repository.dart';
import '../cubit/business_profile_cubit.dart';

/// Business Profile (design "Business Profile"): a gradient cover with back +
/// share, a rounded-square avatar overlapping it, name + verified, role/handle,
/// a business card, bio, a Posts stat (live from the API), a Chat action and the
/// posts grid. Only the Posts count is bound to real data for now; products/tags
/// stay design placeholders until the backend serves them.
class BusinessProfilePage extends StatelessWidget {
  const BusinessProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BusinessProfileCubit>()..load(),
      child: const _BusinessProfileView(),
    );
  }
}

class _BusinessProfileView extends StatelessWidget {
  const _BusinessProfileView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<BusinessProfileCubit, BusinessProfileState>(
        builder: (context, state) {
          if (state.status == BpStatus.loading ||
              state.status == BpStatus.initial) {
            return const LoadingView();
          }
          if (state.status == BpStatus.error || state.user == null) {
            return ErrorView(
              message: state.errorMessage ?? 'Could not load profile',
              onRetry: () => context.read<BusinessProfileCubit>().load(),
            );
          }
          return _Body(user: state.user!, isVerified: state.isVerified);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.user, required this.isVerified});

  final User user;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final topInset = MediaQuery.of(context).padding.top;
    final handle = (user.username ?? '').trim().isNotEmpty
        ? '@${user.username!.trim()}'
        : null;

    return CustomScrollView(
      slivers: [
        // Gradient cover with back + share, and the avatar overlapping it.
        SliverToBoxAdapter(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: topInset + 96,
                decoration: BoxDecoration(gradient: nex.primaryGradient),
                padding: EdgeInsets.only(top: topInset),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.ios_share, color: Colors.white),
                      tooltip: 'Share',
                      onPressed: () => _shareProfile(context, user),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.xl,
                top: topInset + 56,
                child: _SquareAvatar(user: user, background: bg),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 50, AppSpacing.xl, AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + verified.
                Row(
                  children: [
                    Flexible(
                      child: Text(user.businessName ?? user.name,
                          style: texts.titleLarge, overflow: TextOverflow.ellipsis),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Icons.verified, size: 20, color: primary),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(_roleLine(user),
                    style: texts.bodyMedium?.copyWith(color: nex.textSecondary)),

                // Business card.
                if ((user.businessName ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _BusinessCard(user: user, verified: isVerified),
                ],

                // Bio.
                if ((user.bio ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(user.bio!,
                      style: texts.bodyMedium?.copyWith(height: 1.5)),
                ],

                // Posts stat (bound to the API).
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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

                // Chat.
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Chat',
                  icon: Icons.chat_bubble_outline,
                  onPressed: () => _startChat(context, user),
                ),

                if (handle != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(handle,
                      style: texts.labelSmall
                          ?.copyWith(color: nex.textSecondary)),
                ],

                // Posts grid.
                const SizedBox(height: AppSpacing.xl),
                Text('POSTS',
                    style: texts.labelMedium?.copyWith(
                        color: nex.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
                const SizedBox(height: AppSpacing.md),
                _PostsGrid(count: user.postsCount),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _roleLine(User user) {
    if (user.isAdmin) return 'Admin';
    if (user.isBusiness) return 'Business';
    if (user.isCreator) return 'Creator';
    return 'Member';
  }

  Future<void> _shareProfile(BuildContext context, User user) async {
    final link = user.shareUrl ??
        (user.username != null
            ? 'https://nexveero.com/u/${user.username}'
            : null);
    if (link == null) {
      AppOverlays.snack(context, 'No profile link available yet.');
      return;
    }
    await SharePlus.instance.share(
      ShareParams(text: '${user.businessName ?? user.name} on Nexveero\n$link'),
    );
  }

  /// Opens (or reopens) a 1:1 chat with this business via `POST /chats`.
  Future<void> _startChat(BuildContext context, User user) async {
    final repo = sl<ChatRepository>();
    final result = await AppLoader.run(repo.startChat(user.id));
    if (!context.mounted) return;
    switch (result) {
      case Success(value: final conversation):
        context.push(AppRoutes.chatThread, extra: conversation);
      case Err(failure: final f):
        AppOverlays.snack(context, f.message);
    }
  }
}

/// Rounded-square gradient/photo avatar (design radius 24) overlapping the cover.
class _SquareAvatar extends StatelessWidget {
  const _SquareAvatar({required this.user, required this.background});

  final User user;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final imageUrl = MediaUrl.resolve(user.avatarUrl);
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    const size = 82.0;
    final initials = _initials(user.businessName ?? user.name);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: hasImage ? null : nex.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: background, width: 4),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _InitialsText(initials),
            )
          : _InitialsText(initials),
    );
  }
}

class _InitialsText extends StatelessWidget {
  const _InitialsText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24));
}

/// Surface card: business name + verified, then a location · type line.
class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.user, required this.verified});

  final User user;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: nex.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(user.businessName!,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
              if (verified) ...[
                const SizedBox(width: 5),
                Icon(Icons.verified, size: 16, color: primary),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 15, color: nex.iconInactive),
              const SizedBox(width: 5),
              Expanded(
                child: Text('Business account',
                    style: TextStyle(fontSize: 12.5, color: nex.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The posts grid (design placeholders until the posts feed is bound).
class _PostsGrid extends StatelessWidget {
  const _PostsGrid({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    if (count <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text('No posts yet',
              style: TextStyle(color: nex.textSecondary)),
        ),
      );
    }
    final tiles = count > 9 ? 9 : count;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: tiles,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
      ),
      itemBuilder: (context, i) => DecoratedBox(
        decoration: BoxDecoration(
          color: nex.elevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}
