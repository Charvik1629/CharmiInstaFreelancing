import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared URL parsing for chat text, previews and contact link counts.
class MessageLinks {
  static final pattern = RegExp(
    r'(?:https?://|www\.)[^\s<>()]+',
    caseSensitive: false,
  );
  static String normalize(String text) =>
      text.startsWith('www.') ? 'https://$text' : text;
}

class MessageLinkText extends StatefulWidget {
  const MessageLinkText({super.key, required this.text, this.style});
  final String text;
  final TextStyle? style;

  @override
  State<MessageLinkText> createState() => _MessageLinkTextState();
}

class _MessageLinkTextState extends State<MessageLinkText> {
  final _recognizers = <TapGestureRecognizer>[];

  void _clear() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  Future<void> _open(String link) async {
    try {
      final ok = await launchUrl(
        Uri.parse(MessageLinks.normalize(link)),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) _error();
    } catch (_) {
      if (mounted) _error();
    }
  }

  void _error() =>
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open link')));

  @override
  Widget build(BuildContext context) {
    _clear();
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in MessageLinks.pattern.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final link = match.group(0)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _open(link);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: link,
          recognizer: recognizer,
          style: const TextStyle(decoration: TextDecoration.underline),
        ),
      );
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}
