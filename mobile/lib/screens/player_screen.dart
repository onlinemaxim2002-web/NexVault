import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../widgets/common.dart';

/// Online video player (streams from a short-lived signed link; no downloads).
class PlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  const PlayerScreen({super.key, required this.url, required this.title});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final VideoPlayerController _video;
  ChewieController? _chewie;
  String? _error;

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _video
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {
            _chewie = ChewieController(
              videoPlayerController: _video,
              autoPlay: true,
              allowFullScreen: true,
              allowMuting: true,
              showOptions: false,
            );
          });
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = "This video can't be played.");
        });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title, style: const TextStyle(fontSize: 18)),
      ),
      body: Center(
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.white))
            : _chewie == null
            ? const CircularProgressIndicator(color: Colors.white)
            : AspectRatio(
                aspectRatio: _video.value.aspectRatio,
                child: Chewie(controller: _chewie!),
              ),
      ),
    );
  }
}

class ImageViewerScreen extends StatelessWidget {
  final String url;
  final String title;
  const ImageViewerScreen({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(title, style: const TextStyle(fontSize: 18)),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: NetThumb(url: url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
