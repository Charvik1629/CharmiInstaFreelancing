import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/broadcast_detail.dart';
import '../../domain/broadcasts_repository.dart';

/// Broadcast details (design "Broadcast info"): name, recipient count and the
/// full recipient list.
class BroadcastDetailPage extends StatelessWidget {
  const BroadcastDetailPage({super.key, required this.broadcastId, this.initialName});

  final int broadcastId;
  final String? initialName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Broadcast info')),
      body: FutureBuilder<Result<BroadcastDetail>>(
        future: sl<BroadcastsRepository>().getDetail(broadcastId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LoadingView();
          final result = snapshot.data!;
          if (result case Err(failure: final f)) {
            return ErrorView(message: f.message);
          }
          final b = (result as Success<BroadcastDetail>).value;
          final texts = Theme.of(context).textTheme;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.campaign, color: Colors.white, size: 34),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(b.name, style: texts.titleLarge),
                    Text('${b.recipientCount} recipients',
                        style: texts.bodySmall?.copyWith(color: context.nexveero.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('RECIPIENTS',
                  style: texts.labelSmall?.copyWith(
                      color: context.nexveero.textSecondary, letterSpacing: 1)),
              const SizedBox(height: AppSpacing.sm),
              for (final u in b.recipients)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AppAvatar(
                      name: u.name, imageUrl: MediaUrl.resolve(u.avatarUrl), size: 40),
                  title: Text(u.name),
                ),
            ],
          );
        },
      ),
    );
  }
}
