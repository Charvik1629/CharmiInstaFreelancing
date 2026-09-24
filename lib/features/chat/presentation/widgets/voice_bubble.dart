import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A WhatsApp-style voice/audio message: a play/pause button, a seekable
/// progress bar and the running time. The audio streams from [url] and plays
/// in-app (no browser / external app). [mine] tints it for the sender bubble.
class VoiceBubble extends StatefulWidget {
  const VoiceBubble({super.key, required this.url, required this.mine});

  final String url;
  final bool mine;

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _loading = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
      } else if (!_started) {
        setState(() => _loading = true);
        await _player.play(UrlSource(widget.url));
        _started = true;
      } else {
        await _player.resume();
      }
    } catch (_) {
      // Ignore playback errors (bad url / codec) — button just resets.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.mine ? Colors.white : Theme.of(context).colorScheme.primary;
    final track = widget.mine
        ? Colors.white.withValues(alpha: 0.35)
        : context.nexveero.border;
    final total = _duration.inMilliseconds;
    final value =
        total == 0 ? 0.0 : (_position.inMilliseconds / total).clamp(0.0, 1.0);
    final shown = _position > Duration.zero ? _position : _duration;

    return SizedBox(
      width: 210,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fg.withValues(alpha: widget.mine ? 0.22 : 0.12),
                shape: BoxShape.circle,
              ),
              child: _loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                  : Icon(_playing ? Icons.pause : Icons.play_arrow, color: fg),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: fg,
                    inactiveTrackColor: track,
                    thumbColor: fg,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: value,
                    onChanged: total == 0
                        ? null
                        : (v) => _player.seek(Duration(
                            milliseconds: (v * total).round())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(_fmt(shown),
                      style: TextStyle(
                          fontSize: 11,
                          color: widget.mine
                              ? Colors.white70
                              : context.nexveero.textSecondary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
