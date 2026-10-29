import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

/// Full-screen, pinch-to-zoom image viewer that saves straight to the device
/// gallery (asks the runtime photo permission) instead of opening a browser.
/// Shared by the chat thread and the Contact-info media grid.
class FullImageView extends StatefulWidget {
  const FullImageView({super.key, required this.url});
  final String url;

  @override
  State<FullImageView> createState() => _FullImageViewState();
}

class _FullImageViewState extends State<FullImageView> {
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
