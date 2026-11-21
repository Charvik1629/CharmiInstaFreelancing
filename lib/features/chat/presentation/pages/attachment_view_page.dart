import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player/video_player.dart';

class AttachmentViewPage extends StatefulWidget {
  const AttachmentViewPage({
    super.key,
    required this.url,
    required this.name,
    required this.video,
  });
  final String url;
  final String name;
  final bool video;
  @override
  State<AttachmentViewPage> createState() => _AttachmentViewPageState();
}

class _AttachmentViewPageState extends State<AttachmentViewPage> {
  VideoPlayerController? _video;
  Future<void>? _ready;

  @override
  void initState() {
    super.initState();
    if (widget.video) {
      _video = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _ready = _video!.initialize();
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.name)),
    body: widget.video
        ? FutureBuilder<void>(
            future: _ready,
            builder: (context, state) {
              if (state.hasError) {
                return const Center(
                  child: Text('Could not load video. Please try again.'),
                );
              }
              if (state.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: _video!.value.aspectRatio,
                      child: VideoPlayer(_video!),
                    ),
                    VideoProgressIndicator(_video!, allowScrubbing: true),
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _video!,
                      builder: (context, value, _) => IconButton(
                        icon: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                        onPressed: () =>
                            value.isPlaying ? _video!.pause() : _video!.play(),
                      ),
                    ),
                  ],
                ),
              );
            },
          )
        : PdfViewer.uri(Uri.parse(widget.url)),
  );
}
