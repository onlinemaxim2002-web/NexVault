import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../models.dart';
import '../screens/post_screen.dart';
import '../theme.dart';
import 'common.dart';
import 'gates.dart';

/// Chat-style post card used on the channel page and in the Feed.
class PostBubble extends StatelessWidget {
  final Post post;
  final bool showChannel;
  final VoidCallback? onDelete;
  const PostBubble({super.key, required this.post, this.showChannel = false, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cover = post.cover;
    final time = TimeOfDay.fromDateTime(post.publishedAt).format(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: AppColors.bubble, borderRadius: BorderRadius.circular(18)),
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (showChannel)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Row(children: [
                    ChannelAvatar(url: post.channelIcon, name: post.channelName, size: 28),
                    const SizedBox(width: 8),
                    Expanded(child: Text(post.channelName, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                ),
              if (cover != null)
                GestureDetector(
                  onTap: () => post.items.length > 1
                      ? Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostScreen(postId: post.id, initial: post)))
                      : watchItem(context, post, cover),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Stack(fit: StackFit.expand, children: [
                      NetThumb(url: cover.thumbUrl, fallback: cover.isVideo ? Icons.videocam_outlined : Icons.image_outlined),
                      if (cover.isVideo)
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              color: Colors.black38,
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44),
                          ),
                        ),
                      if (cover.isPremium) const Positioned(top: 8, left: 8, child: PremiumBadge()),
                      if (post.items.length > 1)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                            child: Text('+${post.items.length - 1} more',
                                style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ),
                    ]),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(post.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  if (post.caption != null && post.caption!.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(post.caption!, style: const TextStyle(fontSize: 15))),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(time, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 6),
        Column(children: [
          _RoundIcon(
            icon: Icons.more_vert,
            onTap: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: const Text('Open post'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostScreen(postId: post.id, initial: post)));
                    },
                  ),
                  if (onDelete != null)
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: AppColors.primary),
                      title: const Text('Delete post'),
                      onTap: () {
                        Navigator.pop(context);
                        onDelete!();
                      },
                    ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _RoundIcon(
            icon: Icons.reply,
            flip: true,
            onTap: () => SharePlus.instance.share(ShareParams(text: '${post.title} — watch it on ${Config.appName}')),
          ),
        ]),
      ]),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool flip;
  const _RoundIcon({required this.icon, required this.onTap, this.flip = false});

  @override
  Widget build(BuildContext context) {
    final i = Icon(icon, color: Colors.white);
    return InkResponse(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: Color(0xFFBDBDBD), shape: BoxShape.circle),
        child: Center(child: flip ? Transform.flip(flipX: true, child: i) : i),
      ),
    );
  }
}

/// "01 Oct 2025" separator between days.
class DateChip extends StatelessWidget {
  final DateTime date;
  const DateChip({super.key, required this.date});

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final label = '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFF1F1F1), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: const TextStyle(color: AppColors.muted)),
      ),
    );
  }
}
