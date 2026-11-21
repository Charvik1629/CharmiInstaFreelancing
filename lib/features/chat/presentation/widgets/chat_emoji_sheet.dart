import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

/// Emoji insert into the draft; the explicitly labelled quick replies send.
class ChatEmojiSheet extends StatelessWidget {
  const ChatEmojiSheet({
    super.key,
    required this.controller,
    required this.onQuickReply,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQuickReply;
  static const quickReplies = [
    'Hello 👋',
    'Thank you 🙏',
    'Please share the details.',
    'Please share your price.',
    'I am interested.',
    'I will get back to you.',
  ];

  static Future<void> show(
    BuildContext context, {
    required TextEditingController controller,
    required ValueChanged<String> onQuickReply,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ChatEmojiSheet(controller: controller, onQuickReply: onQuickReply),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom) *
            .55,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: TabBar(
                      tabs: [
                        Tab(text: 'Emojis'),
                        Tab(text: 'Quick replies'),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close emoji panel',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    EmojiPicker(
                      textEditingController: controller,
                      config: Config(
                        height: null,
                        emojiViewConfig: EmojiViewConfig(
                          backgroundColor: colors.surface,
                          columns: 7,
                        ),
                        categoryViewConfig: CategoryViewConfig(
                          initCategory: Category.SMILEYS,
                          backgroundColor: colors.surface,
                          indicatorColor: colors.primary,
                          iconColorSelected: colors.primary,
                        ),
                        bottomActionBarConfig: BottomActionBarConfig(
                          backgroundColor: colors.surface,
                          buttonColor: colors.primary,
                        ),
                        searchViewConfig: SearchViewConfig(
                          backgroundColor: colors.surface,
                        ),
                      ),
                    ),
                    ListView(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Tap a quick reply to send it immediately.',
                          ),
                        ),
                        for (final reply in quickReplies)
                          ListTile(
                            title: Text(reply),
                            trailing: const Icon(Icons.send, size: 18),
                            onTap: () {
                              Navigator.pop(context);
                              onQuickReply(reply);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
