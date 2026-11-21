import 'dart:io';

import 'package:flutter/material.dart';

import 'chat_image_editor_page.dart';

class AttachmentDraft {
  const AttachmentDraft({required this.paths, required this.caption});
  final List<String> paths;
  final String caption;
}

class AttachmentCaptionPage extends StatefulWidget {
  const AttachmentCaptionPage({
    super.key,
    required this.paths,
    this.initial = '',
  });
  final List<String> paths;
  final String initial;
  @override
  State<AttachmentCaptionPage> createState() => _AttachmentCaptionPageState();
}

class _AttachmentCaptionPageState extends State<AttachmentCaptionPage> {
  late final _caption = TextEditingController(text: widget.initial);
  late final _paths = List<String>.of(widget.paths);
  int _page = 0;
  bool get _isImage => RegExp(
    r'\.(png|jpe?g|webp|heic)$',
    caseSensitive: false,
  ).hasMatch(_paths[_page]);
  Future<void> _edit() async {
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ChatImageEditorPage(path: _paths[_page]),
      ),
    );
    if (edited != null && mounted) setState(() => _paths[_page] = edited);
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        if (_isImage)
          IconButton(
            tooltip: 'Edit image',
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
      ],
      title: Text(
        '${widget.paths.length} attachment${widget.paths.length == 1 ? '' : 's'}',
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: PageView(
              onPageChanged: (page) => setState(() => _page = page),
              children: [
                for (final path in _paths)
                  Center(
                    child:
                        RegExp(
                          r'\.(png|jpe?g|webp|heic)$',
                          caseSensitive: false,
                        ).hasMatch(path)
                        ? Image.file(
                            File(path),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.image, size: 80),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.attach_file, size: 80),
                              Text(path.split('/').last),
                            ],
                          ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _caption,
                    maxLines: 4,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Add a caption…',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Send attachments',
                  icon: const Icon(Icons.send),
                  onPressed: () => Navigator.of(context).pop(
                    AttachmentDraft(
                      paths: List.unmodifiable(_paths),
                      caption: _caption.text.trim(),
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
