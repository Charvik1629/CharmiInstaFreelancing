import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/chat_message.dart';

class MessageQuote extends StatelessWidget {
  const MessageQuote({
    super.key,
    required this.reply,
    this.meId,
    this.onCancel,
    this.inBubble = false,
  });
  final MessageReply reply;
  final int? meId;
  final VoidCallback? onCancel;
  final bool inBubble;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
    decoration: BoxDecoration(
      color: inBubble
          ? Colors.black.withValues(alpha: .12)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border(
        left: BorderSide(
          color: inBubble
              ? Colors.white70
              : Theme.of(context).colorScheme.primary,
          width: 3,
        ),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reply.senderId != null && reply.senderId == meId
                    ? 'You'
                    : reply.senderName ?? 'Message',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: inBubble
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                reply.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: inBubble
                      ? Colors.white70
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (onCancel != null)
          IconButton(
            tooltip: 'Cancel reply',
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 20),
          ),
      ],
    ),
  );
}

/// Only a completed horizontal gesture selects a reply. The row always returns.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({super.key, required this.child, required this.onReply});
  final Widget child;
  final VoidCallback? onReply;
  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> {
  double _offset = 0;
  bool _dragging = false;
  bool _ready = false;
  @override
  Widget build(BuildContext context) {
    if (widget.onReply == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) {
        final offset = (_offset + d.delta.dx).clamp(0.0, 80.0);
        if (!_ready && offset >= 52) HapticFeedback.selectionClick();
        setState(() {
          _offset = offset;
          _dragging = true;
          _ready = offset >= 52;
        });
      },
      onHorizontalDragEnd: (_) {
        if (_ready) widget.onReply?.call();
        setState(() {
          _offset = 0;
          _dragging = false;
          _ready = false;
        });
      },
      onHorizontalDragCancel: () => setState(() {
        _offset = 0;
        _dragging = false;
        _ready = false;
      }),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_offset > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Opacity(
                opacity: (_offset / 52).clamp(0, 1),
                child: Icon(
                  Icons.reply,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          AnimatedContainer(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 160),
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
