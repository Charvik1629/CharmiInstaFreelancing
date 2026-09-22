import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/link_preview/link_preview_service.dart';
import '../widgets/link_preview_card.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_flow.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../groups/domain/repositories/groups_repository.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/widgets/create_order_sheet.dart';
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
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Location'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _shareLocation();
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Contact'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _shareContact();
            },
          ),
          if (!widget.conversation.isBroadcast)
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Send order'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _createOrder();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _shareLocation() async {
    final label = TextEditingController();
    final lat = TextEditingController();
    final lng = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share location', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(controller: label, label: 'Place', hint: 'Enter place'),
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                Expanded(
                    child: AppTextField(
                        controller: lat,
                        label: 'Lat',
                        keyboardType: TextInputType.number)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: AppTextField(
                        controller: lng,
                        label: 'Lng',
                        keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: AppSpacing.xl),
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.outline,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: 'Send',
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final result = await context.read<ConversationCubit>().sendLocation(
          double.tryParse(lat.text.trim()) ?? 0,
          double.tryParse(lng.text.trim()) ?? 0,
          label.text.trim(),
        );
    if (mounted && !result.isSuccess) {
      AppOverlays.snack(context, result.failureOrNull?.message ?? 'Could not share location');
    }
  }

  Future<void> _shareContact() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share contact', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(controller: name, label: 'Name'),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                  controller: phone,
                  label: 'Phone',
                  keyboardType: TextInputType.phone),
              const SizedBox(height: AppSpacing.xl),
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.outline,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: 'Send',
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final result = await context
        .read<ConversationCubit>()
        .sendContact(name.text.trim(), phone.text.trim());
    if (mounted && !result.isSuccess) {
      AppOverlays.snack(context, result.failureOrNull?.message ?? 'Could not share contact');
    }
  }

  /// Long-press actions on the user's own message: edit (text) / delete.
  /// The server enforces the ≤1h edit and ≤24h delete windows.
  Future<void> _messageActions(ChatMessage msg) async {
    final mine = msg.isMine(widget.meId);
    final action = await AppOverlays.sheet<String>(
      context,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(msg.isStarred ? Icons.star : Icons.star_border),
            title: Text(msg.isStarred ? 'Unstar' : 'Star'),
            onTap: () => Navigator.of(sheetCtx).pop('star'),
          ),
          if (mine &&
              (msg.body ?? '').isNotEmpty &&
              !msg.hasImage &&
              !msg.hasFileAttachment)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.of(sheetCtx).pop('edit'),
            ),
          if (mine)
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(sheetCtx).colorScheme.error),
              title: Text('Delete',
                  style: TextStyle(color: Theme.of(sheetCtx).colorScheme.error)),
              onTap: () => Navigator.of(sheetCtx).pop('delete'),
            ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'star') {
      final result = await context.read<ConversationCubit>().toggleStar(msg);
      if (mounted && !result.isSuccess) {
        AppOverlays.snack(context,
            result.failureOrNull?.message ?? 'Could not update star');
      }
    } else if (action == 'edit') {
      await _editMessage(msg);
    } else if (action == 'delete') {
      final result = await context.read<ConversationCubit>().deleteMessage(msg.id);
      if (mounted && !result.isSuccess) {
        AppOverlays.snack(context,
            result.failureOrNull?.message ?? 'Could not delete message');
      }
    }
  }

  Future<void> _editMessage(ChatMessage msg) async {
    final controller = TextEditingController(text: msg.body);
    final body = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit message',
                  style: Theme.of(ctx).textTheme.titleLarge),
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
    final result = await context.read<ConversationCubit>().editMessage(msg.id, body);
    if (mounted && !result.isSuccess) {
      AppOverlays.snack(
          context, result.failureOrNull?.message ?? 'Could not edit message');
    }
  }

  Future<void> _createOrder() async {
    final order = await CreateOrderSheet.show(context,
        conversationId: widget.conversation.id);
    if (order == null || !mounted) return;
    // Refresh the thread so the order card (returned by the backend as an
    // order-type message) shows up; also confirm inline.
    await context.read<ConversationCubit>().load();
    if (!mounted) return;
    AppOverlays.snack(context, 'Order sent · ${order.amountCredits} credits');
  }

  Future<void> _pickImage(ImageSource source) async {
    final cubit = context.read<ConversationCubit>();
    try {
      if (source == ImageSource.gallery) {
        // Photo Picker needs no permission; allows multiple (up to 5).
        final files =
            await _picker.pickMultiImage(maxWidth: 1600, imageQuality: 85);
        final paths = files.map((f) => f.path).take(5).toList();
        if (paths.isNotEmpty) {
          cubit.sendAttachments(paths, caption: _input.text.trim());
          _input.clear();
        }
      } else {
        final outcome =
            await PermissionFlow.ensure(context, AppPermission.camera);
        if (!outcome.isUsable) return;
        final file = await _picker.pickImage(
            source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
        if (file != null) {
          cubit.sendImage(file.path, caption: _input.text.trim());
          _input.clear();
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
      final files = await FilePicker.pickFiles(allowMultiple: true);
      final paths = [
        for (final f in files) ?f.path,
      ].take(5).toList();
      if (paths.isNotEmpty) {
        cubit.sendAttachments(paths, caption: _input.text.trim());
        _input.clear();
      }
    } catch (_) {
      if (mounted) AppOverlays.snack(context, 'Could not attach file');
    }
  }

  void _voiceComingSoon() =>
      AppOverlays.snack(context, 'Voice messages coming soon.');

  /// Fetches the group by id and opens its Group details screen.
  Future<void> _openGroupInfo(BuildContext context, int groupId) async {
    final result = await AppLoader.run(sl<GroupsRepository>().getGroup(groupId));
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
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: c.isBroadcast
              ? () => context.push(AppRoutes.broadcastDetail, extra: c.id)
              : () => context.push(AppRoutes.contactInfo, extra: c),
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
                  // Live subtitle: typing… › Online › last seen › static label.
                  BlocBuilder<ConversationCubit, ConversationState>(
                    buildWhen: (p, c) =>
                        p.typingName != c.typingName ||
                        p.peerOnline != c.peerOnline ||
                        p.peerLastSeen != c.peerLastSeen,
                    builder: (context, s) {
                      String? line;
                      Color? color;
                      if (s.typingName != null) {
                        line = 'typing…';
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
                      return Text(line,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: color));
                    },
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
        actions: [
          if (c.type == ConversationType.direct)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Contact info',
              onPressed: () => context.push(AppRoutes.contactInfo, extra: c),
            )
          else if (c.type == ConversationType.group && c.groupId != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Group info',
              onPressed: () => _openGroupInfo(context, c.groupId!),
            ),
        ],
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
                                    child: CircularProgressIndicator(strokeWidth: 2))),
                          );
                        }
                        // index 0 → newest (bottom); higher indices → older.
                        final item = items[count - 1 - i];
                        if (item is _DateItem) {
                          return _DateSeparator(date: item.date);
                        }
                        final msg = (item as _MsgItem).message;
                        // Server event lines render as a centered banner.
                        if (msg.isSystem) return _SystemLine(text: msg.body ?? '');
                        final mine = msg.isMine(widget.meId);
                        return GestureDetector(
                          onLongPress: (!msg.isOrder && !msg.isSystem)
                              ? () => _messageActions(msg)
                              : null,
                          child: _Bubble(
                            message: msg,
                            mine: mine,
                            readByPeer: mine &&
                                state.peerLastReadAt != null &&
                                msg.createdAt != null &&
                                !msg.createdAt!.isAfter(state.peerLastReadAt!),
                            showSender:
                                widget.conversation.type == ConversationType.group,
                          ),
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
  const _Bubble(
      {required this.message,
      required this.mine,
      required this.showSender,
      this.readByPeer = false});

  final ChatMessage message;
  final bool mine;
  final bool showSender;
  final bool readByPeer;

  @override
  Widget build(BuildContext context) {
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
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) =>
                    _FullImageView(url: MediaUrl.resolve(message.imageUrl)!),
              )),
              child: ClipRRect(
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
            ),
          if (message.hasFileAttachment) _FileChip(message: message, mine: mine),
          if ((message.body ?? '').isNotEmpty)
            Text(message.body!,
                style: TextStyle(color: mine ? Colors.white : null)),
          if (LinkPreviewService.firstUrl(message.body) case final url?)
            LinkPreviewCard(url: url, mine: mine),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.isStarred) ...[
                Icon(Icons.star,
                    size: 11,
                    color: mine ? Colors.white70 : context.nexveero.warning),
                const SizedBox(width: 3),
              ],
              Text(
                message.createdAt?.timeAgo ?? '',
                style: TextStyle(
                    fontSize: 10,
                    color:
                        mine ? Colors.white70 : context.nexveero.textSecondary),
              ),
              if (mine) ...[
                const SizedBox(width: 3),
                Icon(readByPeer ? Icons.done_all : Icons.done,
                    size: 13,
                    color: readByPeer ? Colors.white : Colors.white70),
              ],
            ],
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
                  child: Text('Order request',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(badge,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
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
                Text('${order.amountCredits} credits',
                    style: texts.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
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
                        onPressed: () => AppOverlays.snack(context,
                            'Order payment is settled by the backend once its pay endpoint is live.'),
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
    final ok = await launchUrl(Uri.parse(full),
        mode: LaunchMode.externalApplication);
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
                        onChanged: (_) =>
                            context.read<ConversationCubit>().notifyTyping(),
                        onSubmitted: (_) => onSend(),
                        // The pill container is the field's surface, so strip
                        // the theme's fill + focus border (else a box-in-a-box).
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          hintText: conversation.isBroadcast
                              ? 'Message all recipients…'
                              : 'Message…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 3),
        decoration: BoxDecoration(
          color: context.nexveero.elevated,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(_label(date),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: context.nexveero.textSecondary)),
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
class _SystemLine extends StatelessWidget {
  const _SystemLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: context.nexveero.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: context.nexveero.textSecondary)),
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom image viewer that saves straight to the device
/// gallery (asks the runtime photo permission) instead of opening a browser.
class _FullImageView extends StatefulWidget {
  const _FullImageView({required this.url});
  final String url;

  @override
  State<_FullImageView> createState() => _FullImageViewState();
}

class _FullImageViewState extends State<_FullImageView> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      // Runtime gallery permission (Gal handles the Android/iOS specifics).
      final granted = await Gal.hasAccess() || await Gal.requestAccess();
      if (!granted) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Gallery permission denied')));
        return;
      }
      final res = await Dio().get<List<int>>(widget.url,
          options: Options(responseType: ResponseType.bytes));
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Could not download image')));
        return;
      }
      await Gal.putImageBytes(Uint8List.fromList(bytes),
          name: 'nexveero_${DateTime.now().millisecondsSinceEpoch}');
      messenger
          .showSnackBar(const SnackBar(content: Text('Saved to gallery')));
    } on GalException catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not save: ${e.type.message}')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not download image')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Save to gallery',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(widget.url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
