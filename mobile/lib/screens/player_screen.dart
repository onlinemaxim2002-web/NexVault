import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/player_controls.dart';

/// Online video player (streams from a short-lived signed link; no downloads).
class PlayerScreen extends StatefulWidget {
  final String url;
  final String title;

  /// Set when playing a trailer: shows a "Watch full video" button.
  final void Function(BuildContext)? onWatchFull;
  const PlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.onWatchFull,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _video;
  ChewieController? _chewie;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open() {
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
              customControls: PremiumPlayerControls(title: widget.title),
              materialProgressColors: ChewieProgressColors(
                playedColor: AppColors.primary,
                handleColor: Colors.white,
                bufferedColor: const Color(0x66FFFFFF),
                backgroundColor: const Color(0x33FFFFFF),
              ),
            );
          });
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = "This video can't be played.");
        });
  }

  void _retry() {
    _chewie?.dispose();
    _video.dispose();
    setState(() {
      _chewie = null;
      _error = null;
    });
    _open();
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _chewie != null && _error == null;
    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: widget.onWatchFull == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "You're watching the trailer",
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.gradient,
                        borderRadius: BorderRadius.circular(Radii.button),
                      ),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: const Icon(Icons.workspace_premium_rounded),
                        label: const Text('Watch full video'),
                        onPressed: () {
                          final navigator = Navigator.of(context);
                          final parent = navigator.context;
                          navigator.pop();
                          widget.onWatchFull!(parent);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _error != null
                  ? _PlayerMessage(
                      icon: Icons.error_outline_rounded,
                      text: _error!,
                      action: FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    )
                  : !ready
                  ? const _PlayerMessage(loading: true, text: 'Loading video…')
                  // Full-screen surface: Chewie keeps the video's aspect
                  // ratio inside; controls and gestures cover the screen.
                  : Chewie(controller: _chewie!),
            ),
            // Before the controls exist, keep a way back + the title.
            if (!ready)
              Positioned(
                top: 4,
                left: 4,
                right: 12,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
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
}

class _PlayerMessage extends StatelessWidget {
  final IconData? icon;
  final String text;
  final bool loading;
  final Widget? action;
  const _PlayerMessage({
    required this.text,
    this.icon,
    this.loading = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            )
          else if (icon != null)
            Icon(icon, color: AppColors.danger, size: 44),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14.5),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0x66000000),
        foregroundColor: Colors.white,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
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
