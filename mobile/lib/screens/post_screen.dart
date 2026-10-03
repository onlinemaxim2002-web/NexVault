import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../models.dart';
import '../services/backend.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gates.dart';
import 'channel_screen.dart';

/// A post's items with Watch buttons ("foods · Posted by - Food").
class PostScreen extends StatefulWidget {
  final String postId;
  final Post? initial;
  const PostScreen({super.key, required this.postId, this.initial});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  Post? post;
  String? error;

  @override
  void initState() {
    super.initState();
    post = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await Backend.post(widget.postId);
      if (!mounted) return;
      setState(() {
        post = p;
        error = p == null ? 'This post is no longer available.' : null;
      });
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = post;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.barGradient),
          child: SizedBox.expand(),
        ),
        titleSpacing: 0,
        title: p == null
            ? const Text('Post')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChannelScreen(channelId: p.channelId),
                      ),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Posted by - '),
                          TextSpan(
                            text: p.channelName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          if (p != null)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share',
              onPressed: () => SharePlus.instance.share(
                ShareParams(text: '${p.title} — watch it on ${Config.appName}'),
              ),
            ),
        ],
      ),
      body: p == null
          ? (error != null
                ? ErrorRetry(message: error!, onRetry: _load)
                : const Center(child: CircularProgressIndicator()))
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (p.caption != null && p.caption!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      p.caption!,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                if (p.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No media in this post.'),
                  ),
                for (final item in p.items) _ItemRow(post: p, item: item),
              ],
            ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Post post;
  final PostItem item;
  const _ItemRow({required this.post, required this.item});

  @override
  Widget build(BuildContext context) {
    final premiumLocked = item.isPremium && !canWatchFull(post, item);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.card + 2),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetThumb(
                    url: item.thumbUrl,
                    fallback: item.isVideo
                        ? Icons.movie_outlined
                        : Icons.image_outlined,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppColors.scrim),
                  ),
                  if (item.isVideo)
                    Center(
                      child: premiumLocked
                          ? Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0x66000000),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x99FFB547),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.lock_rounded,
                                color: AppColors.gold,
                                size: 26,
                              ),
                            )
                          : const PlayOverlay(size: 56),
                    ),
                  if (item.isPremium)
                    const Positioned(top: 10, left: 10, child: PremiumBadge()),
                  if (item.durationS != null)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: ThumbPill(formatDuration(item.durationS!)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (canWatchTrailer(post, item))
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                          ),
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: const Text('Trailer'),
                          onPressed: () => watchTrailer(context, post, item),
                        ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(120, 44),
                        ),
                        icon: Icon(
                          item.isVideo
                              ? Icons.play_arrow_rounded
                              : Icons.image_outlined,
                        ),
                        onPressed: () => watchItem(context, post, item),
                        label: Text(
                          item.isVideo
                              ? (canWatchTrailer(post, item)
                                    ? 'Watch full'
                                    : 'Watch')
                              : 'View',
                        ),
                      ),
                    ],
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
