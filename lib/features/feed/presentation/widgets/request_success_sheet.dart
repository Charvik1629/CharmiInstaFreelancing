import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';

/// "Request sent!" success sheet (design "Request Success", HTML 1520) shown
/// after requesting a post — it auto-creates a private chat. Returns true if the
/// user tapped "Open chat".
class RequestSuccessSheet {
  RequestSuccessSheet._();

  static Future<bool> show(
    BuildContext context, {
    required String peerName,
    String? peerAvatarUrl,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final nex = ctx.nexveero;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: nex.border,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: nex.primaryGradient,
                  ),
                  child: const Icon(Icons.forum, color: Colors.white, size: 44),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Request sent!',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A private chat with $peerName is ready. Say hello to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: nex.textSecondary, height: 1.5),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  decoration: BoxDecoration(
                    color: nex.elevated,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: ListTile(
                    leading: AppAvatar(
                        name: peerName,
                        imageUrl: MediaUrl.resolve(peerAvatarUrl),
                        size: 42),
                    title: Text(peerName,
                        style: Theme.of(ctx).textTheme.titleMedium),
                    subtitle: const Text('Chat created just now'),
                    trailing: Icon(Icons.chevron_right,
                        color: Theme.of(ctx).colorScheme.primary),
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Open chat',
                  icon: Icons.chat_bubble_outline,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Not now'),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }
}
