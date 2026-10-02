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
        titleSpacing: 0,
        title: p == null
            ? const Text('Post')
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChannelScreen(channelId: p.channelId))),
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Posted by - '),
                      TextSpan(text: p.channelName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ),
              ]),
        actions: [
          if (p != null)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share',
              onPressed: () => SharePlus.instance.share(ShareParams(text: '${p.title} — watch it on ${Config.appName}')),
            ),
        ],
      ),
      body: p == null
          ? (error != null ? ErrorRetry(message: error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : ListView(
              children: [
                if (p.caption != null && p.caption!.isNotEmpty)
                  Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(p.caption!, style: const TextStyle(fontSize: 15))),
                if (p.items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No media in this post.')),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 150,
            height: 96,
            child: Stack(fit: StackFit.expand, children: [
              NetThumb(url: item.thumbUrl, fallback: item.isVideo ? Icons.videocam_outlined : Icons.image_outlined),
              if (item.isPremium) const Positioned(top: 6, right: 6, child: PremiumBadge()),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post.title, style: const TextStyle(fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (item.durationS != null)
              Text('${item.durationS! ~/ 60}:${(item.durationS! % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(110, 40), shape: const StadiumBorder()),
              onPressed: () => watchItem(context, post, item),
              child: Text(item.isVideo ? 'Watch' : 'View'),
            ),
          ]),
        ),
      ]),
    );
  }
}
