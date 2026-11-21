import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emojis;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/maps_config.dart';
import '../../../../core/link_preview/link_preview_service.dart';
import 'location_picker_page.dart';
import 'attachment_view_page.dart';
import 'attachment_caption_page.dart';
import '../widgets/voice_recorder_sheet.dart';
import 'location_view_page.dart';
import '../widgets/link_preview_card.dart';
import '../widgets/send_inquiry_sheet.dart';
import '../widgets/voice_bubble.dart';
import '../widgets/chat_emoji_sheet.dart';
import '../widgets/message_reply_widgets.dart';
import '../widgets/message_expiry_status.dart';
import '../widgets/message_reaction_badge.dart';
import '../../domain/entities/message_reaction.dart';
import 'disappearing_messages_page.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/push/push_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_flow.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/widgets/message_link_text.dart';
import '../../../feed/domain/repositories/feed_repository.dart';
import '../../../groups/domain/repositories/groups_repository.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/chat_label.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../wallet/presentation/widgets/overage_dialog.dart';
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
          ConversationCubit(sl<ChatRepository>(), conversation, meId: meId)
            ..load()
            ..loadDetails(),
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
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  final _picker = ImagePicker();

  /// Labels applied to this chat, kept locally so the app-bar dot and the
  /// Labels/Remove-label action update immediately after a change here.
  late List<ChatLabel> _labels = widget.conversation.labels;

  @override
  void initState() {
    super.initState();
    // Suppress foreground push banners for the thread being viewed.
    PushService.setActiveConversation(widget.conversation.id);
    _scroll.addListener(() {
      // The list is reversed (newest at the bottom), so older messages page in
      // when scrolled up toward the top — i.e. near the max scroll extent.
      if (_scroll.hasClients &&
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 40) {
        context.read<ConversationCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    if (PushService.activeConversationId == widget.conversation.id) {
      PushService.setActiveConversation(null);
    }
    _inputFocus.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() => _sendText(_input.text, clearInput: true);

  Future<void> _sendText(String text, {bool clearInput = false}) async {
    if (text.trim().isEmpty) return;
    final cubit = context.read<ConversationCubit>();

    // Broadcast: once the free allowance is spent, each message costs credits.
    // Confirm the debit (design "Free message limit reached") before sending.
    if (cubit.broadcastOverLimit) {
      final cost = cubit.broadcastNextCost;
      final balance = context.read<AuthCubit>().state.user?.creditBalance ?? 0;
      final choice = await OverageDialog.show(
        context,
        cost: cost,
        balance: balance,
        title: 'Free message limit reached',
        message:
            "You've sent ${cubit.broadcastFreeLimit} free broadcast messages. "
            'Sending another will debit $cost credits.',
        debitLabel: 'Debit & send',
      );
      if (!mounted) return;
      switch (choice) {
        case OverageChoice.debit:
          break; // Fall through to send below.
        case OverageChoice.subscribe:
          context.push(AppRoutes.subscription);
          return;
        case OverageChoice.cancel:
          return;
      }
    }

    if (cubit.state.isSending || !cubit.canSend) return;
    await cubit.send(text);
    if (!mounted) return;
    if (clearInput && cubit.state.errorMessage == null && _input.text == text) {
      _input.clear();
    }

    // Fallback: the server rejected the send with the quota-403 (limit over and
    // not enough credits) — surface the unfunded "Broadcast message limit over"
    // dialog, which routes to Subscription.
    if (cubit.state.broadcastLimitReached) {
      cubit.clearBroadcastLimit();
      final cost = cubit.broadcastNextCost;
      final balance = context.read<AuthCubit>().state.user?.creditBalance ?? 0;
      final choice = await OverageDialog.show(
        context,
        cost: cost,
        balance: balance,
        title: 'Broadcast message limit over',
        message: 'Your broadcast message limit is over. You have to subscribe.',
      );
      if (!mounted) return;
      if (choice == OverageChoice.subscribe) {
        context.push(AppRoutes.subscription);
      }
    }
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
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Location'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _shareLocation();
            },
          ),
          // Inquiry — direct chats only (server rejects it elsewhere).
          if (widget.conversation.type == ConversationType.direct)
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Inquiry'),
              subtitle: const Text('Ask with optional price'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _sendInquiry();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _sendInquiry() async {
    final input = await SendInquirySheet.show(context);
    if (input == null || !mounted) return;
    final result = await context.read<ConversationCubit>().sendInquiry(
      input.body,
      input.price,
    );
    if (mounted && !result.isSuccess) {
      AppOverlays.snack(
        context,
        result.failureOrNull?.message ?? 'Could not send inquiry',
      );
    }
  }

  Future<void> _shareLocation() async {
    // WhatsApp-style: pick a spot on the map (or use current location).
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );
    if (picked == null || !mounted) return;
    final result = await context.read<ConversationCubit>().sendLocation(
      picked.lat,
      picked.lng,
      picked.label ?? '',
    );
    if (mounted && !result.isSuccess) {
      AppOverlays.snack(
        context,
        result.failureOrNull?.message ?? 'Could not share location',
      );
    }
  }

  void _replyTo(ChatMessage message) {
    context.read<ConversationCubit>().startReply(message);
    _inputFocus.requestFocus();
  }

  Future<void> _react(ChatMessage message, String? emoji) async {
    final result = await context.read<ConversationCubit>().react(
      message,
      emoji,
    );
    if (mounted && !result.isSuccess) {
      AppOverlays.snack(
        context,
        result.failureOrNull?.message ?? 'Could not update reaction',
      );
    }
  }

  Future<void> _keep(ChatMessage message) async {
    final result = await context.read<ConversationCubit>().keepMessage(message);
    if (mounted && !result.isSuccess) {
      AppOverlays.snack(
        context,
        result.failureOrNull?.message ?? 'Could not keep message',
      );
    }
  }

  Future<String?> _pickReaction() => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .55,
        child: emojis.EmojiPicker(
          onEmojiSelected: (_, emoji) => Navigator.pop(ctx, emoji.emoji),
          config: emojis.Config(
            height: null,
            emojiViewConfig: emojis.EmojiViewConfig(
              backgroundColor: Theme.of(ctx).colorScheme.surface,
            ),
            categoryViewConfig: emojis.CategoryViewConfig(
              initCategory: emojis.Category.SMILEYS,
              backgroundColor: Theme.of(ctx).colorScheme.surface,
            ),
            searchViewConfig: emojis.SearchViewConfig(
              backgroundColor: Theme.of(ctx).colorScheme.surface,
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _messageActions(ChatMessage msg) async {
    _inputFocus.unfocus();
    final mine = msg.isMine(widget.meId);
    final active = msg.canInteract && !msg.hasExpired();
    final canSend = context.read<ConversationCubit>().canSend;
    final action = await AppOverlays.sheet<String>(
      context,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active && canSend && !widget.conversation.isBroadcast)
            Wrap(
              spacing: 2,
              children: [
                for (final emoji in ['👍', '❤️', '😂', '😮', '😢', '🙏'])
                  IconButton(
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 44,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'React $emoji',
                    onPressed: () => Navigator.pop(sheetCtx, 'reaction:$emoji'),
                    icon: Text(emoji, style: const TextStyle(fontSize: 24)),
                    style: IconButton.styleFrom(
                      backgroundColor: msg.myReaction == emoji
                          ? Theme.of(sheetCtx).colorScheme.primaryContainer
                          : null,
                    ),
                  ),
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: 'More reactions',
                  onPressed: () => Navigator.pop(sheetCtx, 'reaction:more'),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          if (active && canSend && !widget.conversation.isBroadcast)
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(sheetCtx, 'reply'),
            ),
          if (active)
            ListTile(
              leading: Icon(msg.isStarred ? Icons.star : Icons.star_border),
              title: Text(msg.isStarred ? 'Unstar' : 'Star'),
              onTap: () => Navigator.pop(sheetCtx, 'star'),
            ),
          if (active && msg.expiresAt != null && !msg.isKept && canSend)
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('Keep'),
              onTap: () => Navigator.pop(sheetCtx, 'keep'),
            ),
          if (mine &&
              active &&
              canSend &&
              (msg.body ?? '').isNotEmpty &&
              !msg.hasImage &&
              !msg.hasFileAttachment)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(sheetCtx, 'edit'),
            ),
          if (!widget.conversation.isBroadcast)
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(sheetCtx).colorScheme.error,
              ),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(sheetCtx, 'delete'),
            ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    if (action.startsWith('reaction:')) {
      final value = action.substring('reaction:'.length);
      final emoji = value == 'more' ? await _pickReaction() : value;
      if (emoji != null && mounted) {
        await _react(msg, emoji);
      }
    } else if (action == 'reply') {
      _replyTo(msg);
    } else if (action == 'keep') {
      await _keep(msg);
    } else if (action == 'star') {
      final result = await context.read<ConversationCubit>().toggleStar(msg);
      if (mounted && !result.isSuccess) {
        AppOverlays.snack(
          context,
          result.failureOrNull?.message ?? 'Could not update star',
        );
      }
    } else if (action == 'edit') {
      await _editMessage(msg);
    } else if (action == 'delete') {
      await _deleteMessage(msg);
    }
  }

  Future<void> _deleteMessage(ChatMessage msg) async {
    final canDeleteEveryone =
        msg.isMine(widget.meId) &&
        !msg.isDeleted &&
        !msg.isSystem &&
        (msg.createdAt == null ||
            DateTime.now().difference(msg.createdAt!) <=
                const Duration(hours: 24));
    final scope = await AppOverlays.sheet<MessageDeleteScope>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Delete message?'),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Delete for me'),
            subtitle: const Text('Other participants keep the message.'),
            onTap: () => Navigator.pop(ctx, MessageDeleteScope.me),
          ),
          if (canDeleteEveryone)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete for everyone'),
              subtitle: const Text(
                'Removes your message for all participants.',
              ),
              onTap: () => Navigator.pop(ctx, MessageDeleteScope.everyone),
            ),
          ListTile(
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
    if (scope == null || !mounted) return;
    final result = await context.read<ConversationCubit>().deleteMessage(
      msg.id,
      scope: scope,
    );
    if (mounted && !result.isSuccess) {
      AppOverlays.snack(
        context,
        result.failureOrNull?.message ?? 'Could not delete message',
      );
    }
  }

  Future<void> _openContactInfo() async {
    final cubit = context.read<ConversationCubit>();
    await context.push(AppRoutes.contactInfo, extra: widget.conversation);
    if (mounted) await cubit.loadDetails();
  }

  Future<void> _openTimer() async {
    final cubit = context.read<ConversationCubit>();
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DisappearingMessagesPage(
          repository: sl<ChatRepository>(),
          initial: cubit.state.disappearing,
          onApply: cubit.setDisappearing,
        ),
      ),
    );
  }

  Future<void> _deleteChat() async {
    final ok = await AppOverlays.confirm(
      context,
      title: 'Delete this chat?',
      message: 'This removes the chat and its history for you. Other participants keep their messages.',
      confirmLabel: 'Delete for me',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final result = await context.read<ConversationCubit>().deleteChat();
    if (mounted && !result.isSuccess) {
      AppOverlays.snack(
        context,
        result.failureOrNull?.message ?? 'Could not delete chat',
      );
    }
  }

  void _showReactions(ChatMessage message) {
    AppOverlays.sheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Reactions')),
          for (final reaction in message.reactions)
            for (final user in reaction.users)
              ListTile(
                leading: Text(
                  reaction.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(user.id == widget.meId ? 'You' : user.name),
              ),
          if (message.myReaction != null)
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Remove my reaction'),
              onTap: () {
                Navigator.pop(ctx);
                _react(message, null);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _editMessage(ChatMessage msg) async {
    final controller = TextEditingController(text: msg.body);
    final body = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit message', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: controller,
                hint: 'Enter message',
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancel',
                      variant: AppButtonVariant.outline,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'Save',
                      onPressed: () =>
                          Navigator.pop(ctx, controller.text.trim()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (body == null || body.isEmpty || !mounted) return;
    final result = await context.read<ConversationCubit>().editMessage(
      msg.id,
      body,
    );
    if (mounted && !result.isSuccess) {
      AppOverlays.snack(
        context,
        result.failureOrNull?.message ?? 'Could not edit message',
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final cubit = context.read<ConversationCubit>();
    try {
      if (source == ImageSource.gallery) {
        // Photo Picker needs no permission; allows multiple (up to 5).
        final files = await _picker.pickMultiImage(
          maxWidth: 1600,
          imageQuality: 85,
        );
        final paths = files.map((f) => f.path).take(5).toList();
        if (paths.isNotEmpty) {
          await _confirmAttachments(cubit, paths);
        }
      } else {
        final outcome = await PermissionFlow.ensure(
          context,
          AppPermission.camera,
        );
        if (!outcome.isUsable) return;
        final file = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (file != null) {
          await _confirmAttachments(cubit, [file.path]);
        }
      }
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
        await _confirmAttachments(cubit, [file.path]);
      }
    } catch (_) {
      if (mounted) AppOverlays.snack(context, 'Could not attach video');
    }
  }

  Future<void> _pickDocument() async {
    final cubit = context.read<ConversationCubit>();
    try {
      final files = await FilePicker.pickFiles();
      final paths = [for (final f in files) ?f.path].take(5).toList();
      if (paths.isNotEmpty) {
        await _confirmAttachments(cubit, paths);
      }
    } catch (_) {
      if (mounted) AppOverlays.snack(context, 'Could not attach file');
    }
  }

  Future<void> _confirmAttachments(
    ConversationCubit cubit,
    List<String> paths,
  ) async {
    if (!mounted || !cubit.canSend) return;
    final originalText = _input.text;
    var currentPaths = paths;
    var currentCaption = originalText.trim();
    while (mounted) {
      final draft = await Navigator.of(context).push<AttachmentDraft>(
        MaterialPageRoute(
          builder: (_) => AttachmentCaptionPage(
            paths: currentPaths,
            initial: currentCaption,
          ),
        ),
      );
      if (draft == null || !mounted) return;
      await cubit.sendAttachments(draft.paths, caption: draft.caption);
      if (!mounted) return;
      if (cubit.state.errorMessage == null) {
        if (_input.text == originalText) _input.clear();
        return;
      }
      currentPaths = draft.paths;
      currentCaption = draft.caption;
    }
  }

  Future<void> _voiceComingSoon() async {
    final cubit = context.read<ConversationCubit>();
    final path = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const VoiceRecorderSheet(),
    );
    if (path != null && mounted) await cubit.sendAttachment(path);
  }

  /// Fetches the linked post and opens its detail (from a question/offer chat).
  Future<void> _viewPost(BuildContext context, int loadId) async {
    final result = await AppLoader.run(sl<FeedRepository>().getLoad(loadId));
    if (!context.mounted) return;
    switch (result) {
      case Success(value: final load):
        context.push(AppRoutes.postDetail, extra: load);
      case Err(failure: final f):
        AppOverlays.snack(context, f.message);
    }
  }

  /// Attach/detach labels on this chat from the thread (so labels can be
  /// managed from the chat detail, not only the chat list). With labels already
  /// applied this is "Remove label" — clears them directly, no picker.
  Future<void> _manageLabels(BuildContext context, Conversation c) async {
    final repo = sl<ChatRepository>();

    // Already labelled → remove directly (no checkbox sheet).
    if (_labels.isNotEmpty) {
      final toRemove = List<ChatLabel>.from(_labels);
      var ok = true;
      for (final l in toRemove) {
        final r = await AppLoader.run(repo.detachLabel(c.id, l.id));
        if (!r.isSuccess) ok = false;
      }
      if (!context.mounted) return;
      if (ok) setState(() => _labels = const []);
      AppOverlays.snack(
        context,
        ok ? 'Label removed' : 'Could not remove label',
      );
      return;
    }

    final result = await AppLoader.run(repo.getLabels());
    if (!context.mounted) return;
    if (result case Err(failure: final f)) {
      AppOverlays.snack(context, f.message);
      return;
    }
    final labels = (result as Success<List<ChatLabel>>).value;
    if (labels.isEmpty) {
      AppOverlays.snack(context, 'Create a label first (Chats → label icon).');
      return;
    }
    final updated = await AppOverlays.sheet<List<ChatLabel>>(
      context,
      builder: (_) =>
          _ThreadLabelSheet(conversation: c, labels: labels, attached: _labels),
    );
    if (updated != null && mounted) {
      setState(() => _labels = updated);
    }
  }

  /// Fetches the group by id and opens its Group details screen.
  Future<void> _openGroupInfo(BuildContext context, int groupId) async {
    final result = await AppLoader.run(
      sl<GroupsRepository>().getGroup(groupId),
    );
    if (!context.mounted) return;
    switch (result) {
      case Success(value: final group):
        context.push(AppRoutes.groupDetail, extra: group);
      case Err(failure: final f):
        AppOverlays.snack(context, f.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    final subtitle = switch (c.type) {
      ConversationType.broadcast => c.subtitle ?? 'Broadcast',
      ConversationType.group => 'Group',
      ConversationType.direct => null,
    };
    return BlocListener<ConversationCubit, ConversationState>(
      listenWhen: (p, n) =>
          p.chatDeleted != n.chatDeleted || p.errorMessage != n.errorMessage,
      listener: (ctx, state) {
        if (state.chatDeleted) {
          ctx.pop('deleted');
        } else if (state.errorMessage != null) {
          AppOverlays.snack(ctx, state.errorMessage!);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: GestureDetector(
            onTap: c.isBroadcast
                ? () => context.push(AppRoutes.broadcastDetail, extra: c.id)
                : _openContactInfo,
            child: Row(
              children: [
                AppAvatar(
                  name: c.title,
                  imageUrl: MediaUrl.resolve(c.avatarUrl),
                  size: 36,
                  enlargeOnTap: true,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          // A colored dot per applied label.
                          for (final l in _labels) ...[
                            const SizedBox(width: 5),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: l.colorValue(
                                  Theme.of(context).colorScheme.primary,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Live subtitle: typing… › Online › last seen › static label.
                      BlocBuilder<ConversationCubit, ConversationState>(
                        buildWhen: (p, c) =>
                            p.typingName != c.typingName ||
                            p.peerOnline != c.peerOnline ||
                            p.peerLastSeen != c.peerLastSeen ||
                            p.disappearing != c.disappearing,
                        builder: (context, s) {
                          String? line;
                          Color? color;
                          if (s.typingName != null) {
                            line = 'typing…';
                            color = Theme.of(context).colorScheme.primary;
                          } else if (s.disappearing.enabled) {
                            line =
                                'Disappears in ${s.disappearing.displayLabel}';
                            color = Theme.of(context).colorScheme.primary;
                          } else if (c.type == ConversationType.direct &&
                              s.peerOnline) {
                            line = 'Online';
                            color = context.nexveero.success;
                          } else if (c.type == ConversationType.direct &&
                              s.peerLastSeen != null) {
                            line = 'last seen ${s.peerLastSeen!.timeAgo}';
                            color = context.nexveero.textSecondary;
                          } else {
                            line = subtitle;
                            color = context.nexveero.textSecondary;
                          }
                          if (line == null) return const SizedBox.shrink();
                          return Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: color),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!c.isBroadcast)
              PopupMenuButton<String>(
                tooltip: 'Chat options',
                onSelected: (action) {
                  if (action == 'timer') _openTimer();
                  if (action == 'delete') _deleteChat();
                },
                itemBuilder: (_) => [
                  if (context.read<ConversationCubit>().canSend)
                    const PopupMenuItem(
                      value: 'timer',
                      child: Text('Disappearing messages'),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete chat'),
                  ),
                ],
              ),
            // Question/offer chats link to a post — let the user open it.
            if (c.loadId != null)
              IconButton(
                icon: const Icon(Icons.receipt_long_outlined),
                tooltip: 'View post',
                onPressed: () => _viewPost(context, c.loadId!),
              ),
            if (!c.isBroadcast)
              IconButton(
                icon: Icon(
                  _labels.isEmpty
                      ? Icons.label_outline
                      : Icons.label_off_outlined,
                ),
                tooltip: _labels.isEmpty ? 'Manage labels' : 'Remove label',
                onPressed: () => _manageLabels(context, c),
              ),
            if (c.type == ConversationType.direct)
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: 'Contact info',
                onPressed: _openContactInfo,
              )
            else if (c.type == ConversationType.group && c.groupId != null)
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: 'Group info',
                onPressed: () => _openGroupInfo(context, c.groupId!),
              ),
          ],
        ),
        body: Container(
          // WhatsApp-style doodle background behind the thread (per theme).
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/chat/chat_bg_dark.jpg'
                    : 'assets/chat/chat_bg_light.jpg',
              ),
              fit: BoxFit.cover,
              repeat: ImageRepeat.repeat,
            ),
          ),
          child: Column(
            children: [
              if (c.isBroadcast) const _BroadcastNotice(),
              if (!c.isBroadcast)
                BlocBuilder<ConversationCubit, ConversationState>(
                  buildWhen: (p, n) => p.disappearing != n.disappearing,
                  builder: (ctx, state) {
                    if (!state.disappearing.enabled) {
                      return const SizedBox.shrink();
                    }
                    return Material(
                      color: Theme.of(ctx).colorScheme.primaryContainer
                          .withValues(alpha: .7),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.timer_outlined, size: 20),
                        title: Text(
                          'New messages disappear after ${state.disappearing.displayLabel}, except when kept.',
                        ),
                        onTap: context.read<ConversationCubit>().canSend
                            ? _openTimer
                            : null,
                      ),
                    );
                  },
                ),
              Expanded(
                child: BlocBuilder<ConversationCubit, ConversationState>(
                  builder: (context, state) {
                    switch (state.status) {
                      case ThreadStatus.loading:
                      case ThreadStatus.initial:
                        return const LoadingView();
                      case ThreadStatus.error:
                        return ErrorView(
                          message:
                              state.errorMessage ?? 'Could not load messages',
                          onRetry: () =>
                              context.read<ConversationCubit>().load(),
                        );
                      case ThreadStatus.empty:
                        return const EmptyView(
                          title: 'No messages yet',
                          subtitle: 'Say hello 👋',
                          icon: Icons.chat_bubble_outline,
                        );
                      case ThreadStatus.loaded:
                        // Interleave day separators (design/web: "Today").
                        final items = _chatItems(state.messages);
                        final count = items.length;
                        return ListView.builder(
                          controller: _scroll,
                          // Reversed so the newest message sits at the bottom and the
                          // view stays pinned there when the keyboard opens.
                          reverse: true,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: count + (state.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, i) {
                            // The loader for older messages sits at the very top,
                            // which in a reversed list is the last builder index.
                            if (state.isLoadingMore && i == count) {
                              return const Padding(
                                padding: EdgeInsets.all(AppSpacing.sm),
                                child: Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }
                            // index 0 → newest (bottom); higher indices → older.
                            final item = items[count - 1 - i];
                            if (item is _DateItem) {
                              return _DateSeparator(date: item.date);
                            }
                            final msg = (item as _MsgItem).message;
                            // Server event lines render as a centered banner.
                            if (msg.isSystem) {
                              return _SystemLine(text: msg.body ?? '');
                            }
                            final mine = msg.isMine(widget.meId);
                            final canReply =
                                context.read<ConversationCubit>().canSend &&
                                !c.isBroadcast &&
                                msg.canInteract &&
                                !msg.hasExpired();
                            return SwipeToReply(
                              key: ValueKey('message-${msg.id}'),
                              onReply: canReply ? () => _replyTo(msg) : null,
                              child: GestureDetector(
                                onLongPress:
                                    !msg.isOrder &&
                                        (!msg.isSystem || msg.isDeleted)
                                    ? () => _messageActions(msg)
                                    : null,
                                child: Column(
                                  crossAxisAlignment: mine
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    _Bubble(
                                      message: msg,
                                      mine: mine,
                                      meId: widget.meId,
                                      onReactions: () => _showReactions(msg),
                                      readByPeer:
                                          mine &&
                                          state.peerLastReadAt != null &&
                                          msg.createdAt != null &&
                                          !msg.createdAt!.isAfter(
                                            state.peerLastReadAt!,
                                          ),
                                      showSender:
                                          c.type == ConversationType.group,
                                    ),
                                    if (!msg.isDeleted)
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.sizeOf(context).width *
                                              .8,
                                        ),
                                        child: Wrap(
                                          spacing: 4,
                                          children: [
                                            if (msg.expiresAt != null ||
                                                msg.isKept)
                                              MessageExpiryStatus(
                                                message: msg,
                                                onKeep:
                                                    state.changingMessages
                                                            .contains(msg.id) ||
                                                        !context
                                                            .read<
                                                              ConversationCubit
                                                            >()
                                                            .canSend
                                                    ? null
                                                    : () => _keep(msg),
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                    }
                  },
                ),
              ),
              BlocBuilder<ConversationCubit, ConversationState>(
                buildWhen: (p, n) => p.replyingTo != n.replyingTo,
                builder: (ctx, state) => state.replyingTo == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: MessageQuote(
                          reply: MessageReply.fromMessage(state.replyingTo!),
                          meId: widget.meId,
                          onCancel: () =>
                              ctx.read<ConversationCubit>().cancelReply(),
                        ),
                      ),
              ),
              _Composer(
                focusNode: _inputFocus,
                controller: _input,
                conversation: c,
                onSend: _send,
                onQuickReply: (text) => _sendText(text),
                onAttach: _openAttachSheet,
                onVoice: _voiceComingSoon,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.showSender,
    this.readByPeer = false,
    this.meId,
    this.onReactions,
  });

  final ChatMessage message;
  final bool mine;
  final bool showSender;
  final bool readByPeer;
  final int? meId;
  final VoidCallback? onReactions;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'This message was deleted',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    // Order messages render as a distinct order card (design "Chat · Order cards").
    if (message.isOrder) {
      return _OrderCard(order: message.order!);
    }
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 16 : 4),
      bottomRight: Radius.circular(mine ? 4 : 16),
    );
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        // Soft solid purple for my bubbles — calmer than the brand gradient and
        // easier on the eyes over the chat background (works in light + dark).
        color: mine ? const Color(0xFF6B5FD6) : context.nexveero.elevated,
        borderRadius: radius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSender && !mine && (message.senderName ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                message.senderName!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: mine ? Colors.white70 : context.nexveero.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (message.replyTo != null || message.replyToMessageId != null)
            MessageQuote(
              reply:
                  message.replyTo ??
                  MessageReply(
                    id: message.replyToMessageId!,
                    body: 'Message unavailable',
                  ),
              meId: meId,
              inBubble: mine,
            ),
          if (message.hasImage)
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) =>
                      FullImageView(url: MediaUrl.resolve(message.imageUrl)!),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  MediaUrl.resolve(message.imageUrl)!,
                  width: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 140,
                    width: 200,
                    child: ImagePlaceholder(role: PlaceholderRole.post),
                  ),
                ),
              ),
            ),
          // Voice/audio → in-app player; other files → chip.
          if (message.attachmentKind == 'audio' &&
              (message.attachmentUrl?.isNotEmpty ?? false))
            VoiceBubble(
              url: MediaUrl.resolve(message.attachmentUrl)!,
              mine: mine,
            )
          else if (message.hasFileAttachment)
            _FileChip(message: message, mine: mine),
          // Location card (type: location) — pin + label, opens a maps app.
          if (message.isLocation)
            _LocationCard(message: message, mine: mine)
          // Inquiry card (type: inquiry) — question + optional price.
          else if (message.isInquiry)
            _InquiryCard(message: message, mine: mine)
          // Offer message — remarks + price, in its own distinct style.
          else if (message.isOffer)
            _OfferCard(message: message, mine: mine)
          else if ((message.body ?? '').isNotEmpty)
            MessageLinkText(
              text: message.body!,
              style: TextStyle(color: mine ? Colors.white : null),
            ),
          if (LinkPreviewService.firstUrl(message.body) case final url?
              when !message.isInquiry && !message.isOffer)
            LinkPreviewCard(url: url, mine: mine),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: [
              if (message.isStarred) ...[
                Icon(
                  Icons.star,
                  size: 11,
                  color: mine ? Colors.white70 : context.nexveero.warning,
                ),
                const SizedBox(width: 3),
              ],
              if (message.editedAt != null)
                Text(
                  'edited · ',
                  style: TextStyle(
                    fontSize: 10,
                    color: mine ? Colors.white70 : null,
                  ),
                ),
              Text(
                message.createdAt?.clockTime ?? '',
                style: TextStyle(
                  fontSize: 10,
                  color: mine ? Colors.white70 : context.nexveero.textSecondary,
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 3),
                // Delivered = grey double-tick; read = blue double-tick.
                Icon(
                  Icons.done_all,
                  size: 13,
                  color: readByPeer ? const Color(0xFF4FC3F7) : Colors.white70,
                ),
              ],
            ],
          ),
        ],
      ),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: message.reactions.isEmpty ? 0 : 14),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            bubble,
            if (message.reactions.isNotEmpty)
              PositionedDirectional(
                start: 10,
                bottom: -9,
                child: MessageReactionBadge(
                  reactions: message.reactions,
                  hasMine: message.myReaction != null,
                  onTap: onReactions ?? () {},
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Order card rendered inline in the thread (design "Chat · Order cards").
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final MessageOrder order;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    final badge = switch (order.status) {
      'paid' || 'completed' => 'PAID',
      'in_progress' => 'IN PROGRESS',
      'cancelled' => 'CANCELLED',
      _ => 'AWAITING',
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: nex.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(gradient: nex.primaryGradient),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Order request',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.title ?? 'Order', style: texts.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '${order.amountCredits} credits',
                  style: texts.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Details',
                        variant: AppButtonVariant.outline,
                        onPressed: () => context.push(
                          AppRoutes.orderDetail,
                          extra: AppOrder(
                            id: order.id,
                            number: order.number,
                            status: order.status,
                            amountCredits: order.amountCredits,
                            title: order.title,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'Pay',
                        onPressed: () => AppOverlays.snack(
                          context,
                          'Order payment is settled by the backend once its pay endpoint is live.',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A one-to-one Inquiry card (design "Inquiry"): an "INQUIRY" label, the
/// question, and an optional price chip.
class _InquiryCard extends StatelessWidget {
  const _InquiryCard({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final accent = mine ? Colors.white : primary;
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: mine
            ? Colors.white.withValues(alpha: 0.14)
            : primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: mine ? 0.4 : 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.help_outline, size: 13, color: accent),
              const SizedBox(width: 5),
              Text(
                'INQUIRY',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message.body ?? '',
            style: TextStyle(color: mine ? Colors.white : null),
          ),
          if ((message.inquiryPrice ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: mine
                    ? Colors.white.withValues(alpha: 0.22)
                    : primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'Price ${message.inquiryPrice}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: mine ? Colors.white : primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// An offer message rendered in its own distinct style — mirrors the design's
/// highlighted Inquiry bubble (accent header + body + price chip) but labelled
/// "OFFER" with the local_offer glyph. The server sends offers as a text
/// message (remarks + an "Offer price:" line), so [message] is split into
/// remarks and a formatted price via [ChatMessage.offerRemarks] / offerPrice.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final accent = mine ? Colors.white : primary;
    final remarks = message.offerRemarks;
    final price = message.offerPrice;
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: mine
            ? Colors.white.withValues(alpha: 0.14)
            : primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: mine ? 0.4 : 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_offer, size: 13, color: accent),
              const SizedBox(width: 5),
              Text(
                'OFFER',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: accent,
                ),
              ),
            ],
          ),
          if (remarks != null) ...[
            const SizedBox(height: 6),
            Text(remarks, style: TextStyle(color: mine ? Colors.white : null)),
          ],
          if ((price ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: mine
                    ? Colors.white.withValues(alpha: 0.22)
                    : primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '₹ $price',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: mine ? Colors.white : primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A shared-location bubble (WhatsApp-style): a static map thumbnail with the
/// place label below; tapping opens the full in-app map screen.
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final lat = message.latitude;
    final lng = message.longitude;
    final label = (message.locationLabel?.isNotEmpty ?? false)
        ? message.locationLabel!
        : (message.body?.isNotEmpty ?? false)
        ? message.body!
        : 'Location';
    if (lat == null || lng == null) {
      // No coordinates — just show the label with a pin.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on,
            size: 18,
            color: mine ? Colors.white : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: mine ? Colors.white : null),
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LocationViewPage(lat: lat, lng: lng, label: label),
        ),
      ),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(top: 2, bottom: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (mine ? Colors.white : context.nexveero.border).withValues(
              alpha: mine ? 0.4 : 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.network(
                MapsConfig.staticMap(lat, lng, width: 440, height: 260),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: context.nexveero.elevated,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.map_outlined,
                    color: context.nexveero.textSecondary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: mine
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: mine ? Colors.white : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: (mine ? Colors.white : context.nexveero.elevated).withValues(
            alpha: mine ? 0.18 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: mine ? Colors.white : null,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.download_rounded, size: 18, color: fg),
          ],
        ),
      ),
    );
  }

  /// Opens/downloads the attachment in the system handler (browser/viewer).
  Future<void> _open(BuildContext context) async {
    final full = MediaUrl.resolve(message.attachmentUrl);
    if (full == null) return;
    if (message.attachmentKind == 'video' ||
        Uri.parse(full).path.toLowerCase().endsWith('.pdf') ||
        (message.attachmentName ?? '').toLowerCase().endsWith('.pdf')) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AttachmentViewPage(
            url: full,
            name: message.attachmentName ?? 'Attachment',
            video: message.attachmentKind == 'video',
          ),
        ),
      );
      return;
    }
    final ok = await launchUrl(
      Uri.parse(full),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      AppOverlays.snack(context, 'Could not open the file');
    }
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
    required this.onQuickReply,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Conversation conversation;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onVoice;

  final ValueChanged<String> onQuickReply;

  void _showQuickReplies(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    ChatEmojiSheet.show(
      context,
      controller: controller,
      onQuickReply: onQuickReply,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!conversation.canChat) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'You can’t reply to this conversation.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.nexveero.textSecondary),
          ),
        ),
      );
    }
    final primary = Theme.of(context).colorScheme.primary;
    // Groups surface an @-mention affordance where direct/broadcast show emoji.
    final fieldIcon = Icons.mood;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
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
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        onChanged: (_) =>
                            context.read<ConversationCubit>().notifyTyping(),
                        // The pill container is the field's surface, so strip
                        // the theme's fill + focus border (else a box-in-a-box).
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          hintText: conversation.isBroadcast
                              ? 'Broadcast message…'
                              : 'Message…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      label: 'Emojis and quick replies',
                      button: true,
                      child: InkWell(
                        onTap: () => _showQuickReplies(context),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            fieldIcon,
                            size: 20,
                            color: context.nexveero.textSecondary,
                          ),
                        ),
                      ),
                    ),
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
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    return IconButton(
                      icon: Icon(
                        hasText ? Icons.send : Icons.mic,
                        color: primary,
                      ),
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

/// One rendered row in the thread: a day separator or a message.
sealed class _ChatItem {}

class _DateItem extends _ChatItem {
  _DateItem(this.date);
  final DateTime date;
}

class _MsgItem extends _ChatItem {
  _MsgItem(this.message);
  final ChatMessage message;
}

/// Groups messages by calendar day, inserting a [_DateItem] before the first
/// message of each day (chronological order).
List<_ChatItem> _chatItems(List<ChatMessage> messages) {
  final items = <_ChatItem>[];
  DateTime? lastDay;
  for (final m in messages) {
    final d = m.createdAt;
    if (d != null) {
      final day = DateTime(d.year, d.month, d.day);
      if (lastDay == null || day != lastDay) {
        items.add(_DateItem(day));
        lastDay = day;
      }
    }
    items.add(_MsgItem(m));
  }
  return items;
}

/// A centered "Today" / "Yesterday" / date chip between message groups.
class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: context.nexveero.elevated,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          _label(date),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: context.nexveero.textSecondary),
        ),
      ),
    );
  }

  String _label(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }
}

/// A server event line ("X requested load …", "Y made an offer …").
/// Info banner at the top of a broadcast thread (design: "Messages are
/// delivered individually to each recipient. Replies come in private chats.").
class _BroadcastNotice extends StatelessWidget {
  const _BroadcastNotice();

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: nex.gradientStart.withValues(alpha: 0.10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Messages are delivered individually to each recipient. '
              'Replies come in private chats.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: nex.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Attach/detach labels on a conversation from the chat thread. Hits
/// attach/detach on [ChatRepository] directly and tracks the attached set
/// locally so the checkboxes update without a full reload.
class _ThreadLabelSheet extends StatefulWidget {
  const _ThreadLabelSheet({
    required this.conversation,
    required this.labels,
    required this.attached,
  });

  final Conversation conversation;
  final List<ChatLabel> labels;
  final List<ChatLabel> attached;

  @override
  State<_ThreadLabelSheet> createState() => _ThreadLabelSheetState();
}

class _ThreadLabelSheetState extends State<_ThreadLabelSheet> {
  late final Set<int> _attached = {for (final l in widget.attached) l.id};
  int? _busyId;

  Future<void> _toggle(ChatLabel l) async {
    final repo = sl<ChatRepository>();
    final attaching = !_attached.contains(l.id);
    setState(() => _busyId = l.id);
    final result = attaching
        ? await repo.attachLabel(widget.conversation.id, l.id)
        : await repo.detachLabel(widget.conversation.id, l.id);
    if (!mounted) return;
    if (result.isSuccess) {
      // Label applied/removed — close the sheet, returning the new label set.
      final ids = Set<int>.from(_attached);
      if (attaching) {
        ids.add(l.id);
      } else {
        ids.remove(l.id);
      }
      final updated = widget.labels.where((x) => ids.contains(x.id)).toList();
      Navigator.of(context).pop(updated);
      return;
    }
    setState(() => _busyId = null);
    AppOverlays.snack(
      context,
      result.failureOrNull?.message ?? 'Could not update label',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Labels for ${widget.conversation.title}',
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final l in widget.labels)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: l.colorValue(
                          Theme.of(context).colorScheme.primary,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(l.name),
                    value: _attached.contains(l.id),
                    onChanged: _busyId != null ? null : (_) => _toggle(l),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SystemLine extends StatelessWidget {
  const _SystemLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: context.nexveero.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.nexveero.textSecondary),
        ),
      ),
    );
  }
}
