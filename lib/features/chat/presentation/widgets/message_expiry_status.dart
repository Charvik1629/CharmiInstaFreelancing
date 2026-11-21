import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/entities/chat_message.dart';

class MessageExpiryStatus extends StatefulWidget {
  const MessageExpiryStatus({
    super.key,
    required this.message,
    required this.onKeep,
  });
  final ChatMessage message;
  final VoidCallback? onKeep;
  @override
  State<MessageExpiryStatus> createState() => _MessageExpiryStatusState();
}

class _MessageExpiryStatusState extends State<MessageExpiryStatus> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _remaining {
    final remaining = widget.message.expiresAt!.difference(DateTime.now());
    if (remaining.inDays > 0) {
      return '${remaining.inDays}d ${remaining.inHours.remainder(24)}h';
    }
    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
    }
    return remaining.inMinutes > 0 ? '${remaining.inMinutes}m' : 'Expires soon';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.isKept) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark, size: 14, color: Colors.green),
          SizedBox(width: 3),
          Text('Kept', style: TextStyle(color: Colors.green, fontSize: 11)),
        ],
      );
    }
    if (widget.message.expiresAt == null || widget.message.isDeleted) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer_outlined, size: 14),
        const SizedBox(width: 4),
        Text(_remaining, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: widget.onKeep,
          icon: const Icon(Icons.bookmark_border, size: 14),
          label: const Text('Keep'),
        ),
      ],
    );
  }
}
