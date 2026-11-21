import 'package:flutter/material.dart';

import '../../domain/entities/message_reaction.dart';

/// A small pill that sits across the bubble edge; the list opens on tap.
class MessageReactionBadge extends StatelessWidget {
  const MessageReactionBadge({
    super.key,
    required this.reactions,
    required this.onTap,
    this.hasMine = false,
  });
  final List<MessageReaction> reactions;
  final VoidCallback onTap;
  final bool hasMine;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = reactions.fold<int>(0, (sum, r) => sum + r.count);
    return Semantics(
      label:
          'Message reactions: ${reactions.map((r) => '${r.emoji} ${r.count}').join(', ')}',
      button: true,
      child: Material(
        elevation: 1,
        color: colors.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: hasMine
                ? colors.primary.withValues(alpha: .3)
                : colors.outlineVariant,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final reaction in reactions.take(3))
                  Text(
                    reaction.emoji,
                    style: const TextStyle(fontSize: 15, height: 1.25),
                  ),
                if (count > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
