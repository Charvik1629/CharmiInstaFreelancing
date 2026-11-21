import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Pixel transforms run away from the UI isolate. Input files are never changed.
Uint8List transformChatImage(Map<String, Object> input) {
  final decoded = img.decodeImage(input['bytes'] as Uint8List);
  if (decoded == null) throw const FormatException('Unsupported image');
  var image = img.bakeOrientation(decoded);
  switch (input['operation']) {
    case 'rotate':
      image = img.copyRotate(image, angle: 90);
    case 'flip':
      image = img.flipHorizontal(image);
    case 'crop':
      final rect = input['rect'] as List<double>;
      final x = (rect[0] * image.width).round().clamp(0, image.width - 1);
      final y = (rect[1] * image.height).round().clamp(0, image.height - 1);
      image = img.copyCrop(
        image,
        x: x,
        y: y,
        width: (rect[2] * image.width).round().clamp(1, image.width - x),
        height: (rect[3] * image.height).round().clamp(1, image.height - y),
      );
  }
  return Uint8List.fromList(img.encodePng(image));
}

class ChatImageEditorPage extends StatefulWidget {
  const ChatImageEditorPage({super.key, required this.path});
  final String path;
  @override
  State<ChatImageEditorPage> createState() => _ChatImageEditorPageState();
}

class _Stroke {
  _Stroke(this.color, this.points);
  final Color color;
  final List<Offset> points;
}

class _ImageText {
  _ImageText(this.text, this.color);
  final String text;
  final Color color;
  Offset position = const Offset(.1, .45);
}

class _ChatImageEditorPageState extends State<ChatImageEditorPage> {
  ui.Image? _image;
  bool _busy = true;
  String? _error;
  String _mode = 'draw';
  Color _color = Colors.red;
  final List<_Stroke> _strokes = [];
  final List<_ImageText> _texts = [];
  Rect _crop = const Rect.fromLTWH(.1, .1, .8, .8);
  int? _corner;

  @override
  void initState() {
    super.initState();
    _loadOriginal();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _loadOriginal() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _decode(await File(widget.path).readAsBytes());
      _strokes.clear();
      _texts.clear();
      _crop = const Rect.fromLTWH(.1, .1, .8, .8);
    } catch (_) {
      _error = 'Could not open this image. You can still send the original.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      final old = _image;
      _image = frame.image;
      old?.dispose();
    } finally {
      codec.dispose();
    }
  }

  Future<Uint8List> _flatten() async {
    final image = _image!;
    final recorder = ui.PictureRecorder();
    _EditPainter(image, _strokes, _texts).paint(
      Canvas(recorder),
      Size(image.width.toDouble(), image.height.toDouble()),
    );
    final picture = recorder.endRecording();
    final flattened = await picture.toImage(image.width, image.height);
    picture.dispose();
    try {
      final data = await flattened.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const FormatException('Image export failed');
      return data.buffer.asUint8List();
    } finally {
      flattened.dispose();
    }
  }

  Future<void> _transform(String operation) async {
    if (_busy || _image == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await _flatten();
      final transformed = await compute(transformChatImage, <String, Object>{
        'bytes': bytes,
        'operation': operation,
        'rect': <double>[_crop.left, _crop.top, _crop.width, _crop.height],
      });
      await _decode(transformed);
      _strokes.clear();
      _texts.clear();
      _crop = const Rect.fromLTWH(.1, .1, .8, .8);
      if (operation == 'crop') _mode = 'draw';
    } catch (_) {
      _error = 'Could not edit this image. Try again.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() async {
    if (_busy || _image == null) return;
    if (_mode == 'crop') {
      await _transform('crop');
      if (!mounted || _error != null) return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await _flatten();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/chat_edit_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (mounted) Navigator.pop(context, file.path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save the edit. Your original is unchanged.';
        });
      }
    }
  }

  Future<void> _addText() async {
    var entered = '';
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add text'),
        content: TextField(
          onChanged: (value) => entered = value,
          autofocus: true,
          maxLength: 100,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, entered.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (!mounted || text == null || text.isEmpty) return;
    setState(() {
      _texts.add(_ImageText(text, _color));
      _mode = 'text';
    });
  }

  Offset _normal(Offset p, Size size) =>
      Offset((p.dx / size.width).clamp(0, 1), (p.dy / size.height).clamp(0, 1));

  void _panStart(DragStartDetails d, Size size) {
    final p = _normal(d.localPosition, size);
    setState(() {
      if (_mode == 'draw') _strokes.add(_Stroke(_color, [p]));
      if (_mode == 'crop') {
        final corners = [
          _crop.topLeft,
          _crop.topRight,
          _crop.bottomLeft,
          _crop.bottomRight,
        ];
        _corner = 0;
        for (var i = 1; i < 4; i++) {
          if ((corners[i] - p).distance < (corners[_corner!] - p).distance) {
            _corner = i;
          }
        }
      }
    });
  }

  void _panUpdate(DragUpdateDetails d, Size size) {
    final p = _normal(d.localPosition, size);
    setState(() {
      if (_mode == 'draw' && _strokes.isNotEmpty) _strokes.last.points.add(p);
      if (_mode == 'text' && _texts.isNotEmpty) _texts.last.position = p;
      if (_mode == 'crop' && _corner != null) {
        final left = _corner!.isEven
            ? math.min(p.dx, _crop.right - .05)
            : _crop.left;
        final right = _corner!.isOdd
            ? math.max(p.dx, _crop.left + .05)
            : _crop.right;
        final top = _corner! < 2
            ? math.min(p.dy, _crop.bottom - .05)
            : _crop.top;
        final bottom = _corner! >= 2
            ? math.max(p.dy, _crop.top + .05)
            : _crop.bottom;
        _crop = Rect.fromLTRB(left, top, right, bottom);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Edit image'),
      actions: [
        TextButton(
          onPressed: _busy ? null : _loadOriginal,
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: _busy || _image == null ? null : _save,
          child: const Text('Done'),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: _busy
                ? const Center(child: CircularProgressIndicator())
                : _image == null
                ? const Center(
                    child: Icon(Icons.broken_image_outlined, size: 64),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _image!.width / _image!.height,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final size = box.biggest;
                            return GestureDetector(
                              onPanStart: (d) => _panStart(d, size),
                              onPanUpdate: (d) => _panUpdate(d, size),
                              child: CustomPaint(
                                size: size,
                                painter: _EditPainter(
                                  _image!,
                                  _strokes,
                                  _texts,
                                  crop: _mode == 'crop' ? _crop : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),
          if (_mode == 'crop')
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Flexible(child: Text('Drag the corners to crop.')),
                  TextButton(
                    onPressed: _busy ? null : () => _transform('crop'),
                    child: const Text('Apply crop'),
                  ),
                ],
              ),
            ),
          if (_mode == 'text')
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Drag to position the last text label.'),
            ),
          if (_mode == 'draw' || _mode == 'text')
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final color in [
                  Colors.red,
                  Colors.amber,
                  Colors.green,
                  Colors.blue,
                  Colors.white,
                  Colors.black,
                ])
                  IconButton(
                    tooltip: 'Select ${color.toARGB32().toRadixString(16)}',
                    onPressed: _busy
                        ? null
                        : () => setState(() => _color = color),
                    icon: Icon(
                      _color == color ? Icons.check_circle : Icons.circle,
                      color: color,
                    ),
                  ),
              ],
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _mode = 'crop'),
                  icon: const Icon(Icons.crop),
                  label: const Text('Crop'),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : () => _transform('rotate'),
                  icon: const Icon(Icons.rotate_right),
                  label: const Text('Rotate'),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : () => _transform('flip'),
                  icon: const Icon(Icons.flip),
                  label: const Text('Flip'),
                ),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _mode = 'draw'),
                  icon: const Icon(Icons.draw),
                  label: const Text('Draw'),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _addText,
                  icon: const Icon(Icons.text_fields),
                  label: const Text('Text'),
                ),
                IconButton(
                  tooltip: 'Undo annotation',
                  onPressed: _busy || (_strokes.isEmpty && _texts.isEmpty)
                      ? null
                      : () => setState(() {
                          if (_mode == 'text' && _texts.isNotEmpty) {
                            _texts.removeLast();
                          } else if (_strokes.isNotEmpty) {
                            _strokes.removeLast();
                          } else {
                            _texts.removeLast();
                          }
                        }),
                  icon: const Icon(Icons.undo),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EditPainter extends CustomPainter {
  _EditPainter(this.image, this.strokes, this.texts, {this.crop});
  final ui.Image image;
  final List<_Stroke> strokes;
  final List<_ImageText> texts;
  final Rect? crop;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      area,
      Paint(),
    );
    canvas.save();
    canvas.clipRect(area);
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = size.shortestSide * .008
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < stroke.points.length; i++) {
        final a = stroke.points[i];
        final b = stroke.points[math.max(0, i - 1)];
        canvas.drawLine(
          Offset(a.dx * size.width, a.dy * size.height),
          Offset(b.dx * size.width, b.dy * size.height),
          paint,
        );
      }
    }
    for (final text in texts) {
      final painter = TextPainter(
        text: TextSpan(
          text: text.text,
          style: TextStyle(
            color: text.color,
            fontSize: size.shortestSide * .065,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * .9);
      painter.paint(
        canvas,
        Offset(text.position.dx * size.width, text.position.dy * size.height),
      );
      painter.dispose();
    }
    canvas.restore();
    if (crop case final r?) {
      final rect = Rect.fromLTRB(
        r.left * size.width,
        r.top * size.height,
        r.right * size.width,
        r.bottom * size.height,
      );
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(area),
          Path()..addRect(rect),
        ),
        Paint()..color = Colors.black54,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (final corner in [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ]) {
        canvas.drawCircle(corner, 7, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EditPainter oldDelegate) => true;
}
