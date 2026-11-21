import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Recording is never uploaded until the user explicitly presses Send.
class VoiceRecorderSheet extends StatefulWidget {
  const VoiceRecorderSheet({super.key});
  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet>
    with WidgetsBindingObserver {
  final _recorder = AudioRecorder();
  Timer? _timer;
  int _seconds = 0;
  bool _recording = false;
  bool _finishing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          setState(() => _error = 'Microphone permission is required.');
        }
        return;
      }
      final directory = await getTemporaryDirectory();
      if (!mounted) return;
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path:
            '${directory.path}/voice-${DateTime.now().microsecondsSinceEpoch}.m4a',
      );
      if (!mounted) {
        await _recorder.cancel();
        return;
      }
      setState(() => _recording = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not start recording. Try again.');
      }
    }
  }

  Future<void> _finish() async {
    if (!_recording || _finishing) return;
    _finishing = true;
    _timer?.cancel();
    try {
      final path = await _recorder.stop();
      if (mounted) Navigator.of(context).pop(path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not save recording.';
          _finishing = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic, size: 40, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            _error ??
                (_recording
                    ? 'Recording ${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}'
                    : 'Starting recorder…'),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _recording && !_finishing && _seconds > 0
                    ? _finish
                    : null,
                child: const Text('Send voice message'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
