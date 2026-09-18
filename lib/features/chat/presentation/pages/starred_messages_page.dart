import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';

/// "Starred messages" (GET /messages/starred) — every message you've starred,
/// across conversations. Tapping one opens its thread.
class StarredMessagesPage extends StatefulWidget {
  const StarredMessagesPage({super.key});

  @override
  State<StarredMessagesPage> createState() => _StarredMessagesPageState();
}

class _StarredMessagesPageState extends State<StarredMessagesPage> {
  late Future<Result<List<ChatMessage>>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<ChatRepository>().getStarredMessages();
  }

  void _reload() => setState(
      () => _future = sl<ChatRepository>().getStarredMessages());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Starred messages')),
      body: FutureBuilder<Result<List<ChatMessage>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingView();
          final result = snap.data!;
          switch (result) {
            case Err(failure: final f):
              return ErrorView(message: f.message, onRetry: _reload);
            case Success(value: final messages):
              if (messages.isEmpty) {
                return const EmptyView(
                  title: 'No starred messages',
                  subtitle: 'Long-press a message and tap Star to save it here.',
                  icon: Icons.star_border,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: messages.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, indent: 16, color: context.nexveero.border),
                itemBuilder: (context, i) => _StarredTile(message: messages[i]),
              );
          }
        },
      ),
    );
  }
}

class _StarredTile extends StatelessWidget {
  const _StarredTile({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final preview = (message.body ?? '').isNotEmpty
        ? message.body!
        : (message.hasImage
            ? '📷 Photo'
            : (message.hasFileAttachment ? '📎 Attachment' : 'Message'));
    return ListTile(
      leading: Icon(Icons.star, color: context.nexveero.warning),
      title: Text(message.senderName ?? 'Message',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: texts.titleSmall),
      subtitle: Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: message.createdAt != null
          ? Text(message.createdAt!.timeAgo,
              style: texts.labelSmall
                  ?.copyWith(color: context.nexveero.textSecondary))
          : null,
      onTap: message.conversationId == null
          ? null
          : () => context.push(
                AppRoutes.chatThread,
                extra: Conversation(
                  id: message.conversationId!,
                  type: ConversationType.direct,
                  title: message.senderName ?? 'Chat',
                ),
              ),
    );
  }
}
