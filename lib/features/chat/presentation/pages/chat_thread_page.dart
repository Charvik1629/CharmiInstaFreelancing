import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_flow.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../cubit/conversation_cubit.dart';

/// A single chat thread (direct, group or broadcast). Broadcasts are one-to-many
/// so there's no "other side" — the composer still sends to all recipients.
class ChatThreadPage extends StatelessWidget {
  const ChatThreadPage({super.key, required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final meId = context.read<AuthCubit>().state.user?.id;
    return BlocProvider(
      create: (_) =>
          ConversationCubit(sl<ChatRepository>(), conversation, meId: meId)..load(),
      child: _ThreadView(conversation: conversation, meId: meId),
    );
  }
}

class _ThreadView extends StatefulWidget {
  const _ThreadView({required this.conversation, required this.meId});

  final Conversation conversation;
  final int? meId;

  @override
  State<_ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<_ThreadView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Older messages page in when scrolled to the top.
      if (_scroll.position.pixels <= 40) {
        context.read<ConversationCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    context.read<ConversationCubit>().send(text);
    _input.clear();
  }

  /// The "+" attachment menu (design: Photo · Camera · File).
  void _openAttachSheet() {
    AppOverlays.sheet<void>(
      context,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Photo'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Camera'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: const Text('Video'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _pickVideo();
            },
          ),
          ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: const Text('Document'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _pickDocument();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final cubit = context.read<ConversationCubit>();
    final permission =
        source == ImageSource.camera ? AppPermission.camera : AppPermission.photos;
    final outcome = await PermissionFlow.ensure(context, permission);
    if (!outcome.isUsable) return;
    try {
      final file =
          await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (file != null) cubit.sendImage(file.path, caption: _input.text.trim());
      _input.clear();
    } catch (_) {
      if (mounted) AppOverlays.snack(context, 'Could not attach image');
    }
  }

  Future<void> _pickVideo() async {
    final cubit = context.read<ConversationCubit>();
    final outcome = await PermissionFlow.ensure(context, AppPermission.photos);
    if (!outcome.isUsable) return;
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null) {
        cubit.sendAttachment(file.path, caption: _input.text.trim());
        _input.clear();
      }
    } catch (_) {
      if (mounted) AppOverlays.snack(context, 'Could not attach video');
    }
  }

  Future<void> _pickDocument() async {
    final cubit = context.read<ConversationCubit>();
    try {
      final files = await FilePicker.pickFiles();
      final path = files.isEmpty ? null : files.first.path;
      if (path != null) {
        cubit.sendAttachment(path, caption: _input.text.trim());
        _input.clear();
      }
    } catch (_) {
      if (mounted) AppOverlays.snack(context, 'Could not attach file');
    }
  }

  void _voiceComingSoon() =>
      AppOverlays.snack(context, 'Voice messages coming soon.');

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    final subtitle = switch (c.type) {
      ConversationType.broadcast => c.subtitle ?? 'Broadcast',
      ConversationType.group => 'Group',
      ConversationType.direct => null,
    };
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: c.isBroadcast
              ? () => context.push(AppRoutes.broadcastDetail, extra: c.id)
              : null,
          child: Row(
          children: [
            AppAvatar(name: c.title, imageUrl: MediaUrl.resolve(c.avatarUrl), size: 36),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (subtitle != null)
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: context.nexveero.textSecondary)),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ConversationCubit, ConversationState>(
              builder: (context, state) {
                switch (state.status) {
                  case ThreadStatus.loading:
                  case ThreadStatus.initial:
                    return const LoadingView();
                  case ThreadStatus.error:
                    return ErrorView(
                      message: state.errorMessage ?? 'Could not load messages',
                      onRetry: () => context.read<ConversationCubit>().load(),
                    );
                  case ThreadStatus.empty:
                    return const EmptyView(
                      title: 'No messages yet',
                      subtitle: 'Say hello 👋',
                      icon: Icons.chat_bubble_outline,
                    );
                  case ThreadStatus.loaded:
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: state.messages.length + (state.isLoadingMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (state.isLoadingMore && i == 0) {
                          return const Padding(
                            padding: EdgeInsets.all(AppSpacing.sm),
                            child: Center(
                                child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))),
                          );
                        }
                        final index = state.isLoadingMore ? i - 1 : i;
                        final msg = state.messages[index];
                        return _Bubble(
                          message: msg,
                          mine: msg.isMine(widget.meId),
                          showSender: widget.conversation.type == ConversationType.group,
                        );
                      },
                    );
                }
              },
            ),
          ),
          _Composer(
            controller: _input,
            conversation: c,
            onSend: _send,
            onAttach: _openAttachSheet,
            onVoice: _voiceComingSoon,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.showSender});

  final ChatMessage message;
  final bool mine;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 16 : 4),
      bottomRight: Radius.circular(mine ? 4 : 16),
    );
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: mine ? context.nexveero.primaryGradient : null,
        color: mine ? null : context.nexveero.elevated,
        borderRadius: radius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSender && !mine && (message.senderName ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(message.senderName!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: mine ? Colors.white70 : context.nexveero.textSecondary,
                      fontWeight: FontWeight.w700)),
            ),
          if (message.hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                MediaUrl.resolve(message.imageUrl)!,
                width: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                    height: 140,
                    width: 200,
                    child: ImagePlaceholder(role: PlaceholderRole.post)),
              ),
            ),
          if (message.hasFileAttachment) _FileChip(message: message, mine: mine),
          if ((message.body ?? '').isNotEmpty)
            Text(message.body!,
                style: TextStyle(color: mine ? Colors.white : null)),
          const SizedBox(height: 2),
          Text(
            message.createdAt?.timeAgo ?? '',
            style: TextStyle(
                fontSize: 10,
                color: mine ? Colors.white70 : context.nexveero.textSecondary),
          ),
        ],
      ),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
    );
  }
}

/// Inline chip for a non-image attachment (video / voice / document).
class _FileChip extends StatelessWidget {
  const _FileChip({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final kind = message.attachmentKind;
    final (icon, fallback) = switch (kind) {
      'video' => (Icons.play_circle_outline, 'Video'),
      'audio' => (Icons.mic_none, 'Voice message'),
      _ => (Icons.insert_drive_file_outlined, 'Document'),
    };
    final label = (message.attachmentName?.isNotEmpty ?? false)
        ? message.attachmentName!
        : fallback;
    final fg = mine ? Colors.white : context.nexveero.textSecondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: (mine ? Colors.white : context.nexveero.elevated)
            .withValues(alpha: mine ? 0.18 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: mine ? Colors.white : null,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// Chat composer matching the design: a "+" attach button, the text field with
/// an emoji (or @-mention for groups) affordance, and a trailing button that is
/// a mic when the field is empty and a send button once you type.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.conversation,
    required this.onSend,
    required this.onAttach,
    required this.onVoice,
  });

  final TextEditingController controller;
  final Conversation conversation;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    if (!conversation.canChat) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('You can’t reply to this conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.nexveero.textSecondary)),
        ),
      );
    }
    final primary = Theme.of(context).colorScheme.primary;
    // Groups surface an @-mention affordance where direct/broadcast show emoji.
    final fieldIcon =
        conversation.type == ConversationType.group ? Icons.alternate_email : Icons.mood;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: context.nexveero.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: primary),
              tooltip: 'Attach',
              onPressed: onAttach,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.nexveero.elevated,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: conversation.isBroadcast
                              ? 'Message all recipients…'
                              : 'Message…',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    Icon(fieldIcon, size: 20, color: context.nexveero.textSecondary),
                  ],
                ),
              ),
            ),
            // Trailing action: sending spinner → send (has text) → mic (empty).
            BlocSelector<ConversationCubit, ConversationState, bool>(
              selector: (s) => s.isSending,
              builder: (context, sending) {
                if (sending) {
                  return const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                return ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    return IconButton(
                      icon: Icon(hasText ? Icons.send : Icons.mic, color: primary),
                      tooltip: hasText ? 'Send' : 'Voice message',
                      onPressed: hasText ? onSend : onVoice,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
