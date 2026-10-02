import 'package:flutter/material.dart';

import '../models.dart';
import '../services/backend.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gates.dart';
import '../widgets/post_bubble.dart';
import 'new_post_screen.dart';

/// Channel page: Telegram-style stream of posts, Join bar, and (for the
/// creator of an approved channel) a button to post.
class ChannelScreen extends StatefulWidget {
  final String channelId;
  const ChannelScreen({super.key, required this.channelId});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  Channel? channel;
  List<Post>? posts;
  List<Folder> folders = [];
  String? folderId;
  bool joined = false;
  String? error;

  bool get isCreator =>
      channel?.createdBy != null && channel!.createdBy == app.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Backend.channel(widget.channelId),
        Backend.channelPosts(widget.channelId),
        Backend.folders(widget.channelId),
        Backend.joinedChannelIds(),
      ]);
      if (!mounted) return;
      setState(() {
        channel = results[0] as Channel?;
        posts = results[1] as List<Post>;
        folders = results[2] as List<Folder>;
        joined = (results[3] as Set<String>).contains(widget.channelId);
        error = channel == null ? 'This channel is not available.' : null;
      });
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
  }

  Future<void> _join() async {
    if (!await ensureLoggedIn(context, reason: 'Log in to join channels')) {
      return;
    }
    try {
      await Backend.join(widget.channelId);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _leave() async {
    try {
      await Backend.leave(widget.channelId);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _deletePost(Post p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete post?'),
        content: Text('"${p.title}" will be removed from the channel.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Backend.deletePost(p.id);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = channel;
    final approved = c?.reviewStatus == 'approved';
    final shown = posts == null
        ? null
        : (folderId == null
              ? posts!
              : posts!.where((p) => p.folderId == folderId).toList());

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: c == null
            ? const Text('Channel')
            : Row(
                children: [
                  ChannelAvatar(url: c.iconUrl, name: c.name, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 18,
                              color: Colors.white,
                            ),
                            Text(
                              ' ${c.membersCount}   ',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            const Icon(
                              Icons.folder_outlined,
                              size: 18,
                              color: Colors.white,
                            ),
                            Text(
                              ' ${c.foldersCount}',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          if (joined && !isCreator)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'leave' ? _leave() : null,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'leave', child: Text('Leave channel')),
              ],
            ),
        ],
      ),
      floatingActionButton: isCreator && approved
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: 'New post',
              onPressed: () async {
                final posted = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        NewPostScreen(channelId: c!.id, channelName: c.name),
                  ),
                );
                if (posted == true) _load();
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: c == null
          ? (error != null
                ? ErrorRetry(message: error!, onRetry: _load)
                : const Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                if (isCreator && !approved)
                  _ReviewBanner(status: c.reviewStatus),
                if (folders.isNotEmpty)
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      children: [
                        _folderChip(null, 'All'),
                        for (final f in folders) _folderChip(f.id, f.name),
                      ],
                    ),
                  ),
                Expanded(
                  child: shown == null
                      ? const Center(child: CircularProgressIndicator())
                      : shown.isEmpty
                      ? EmptyState(
                          message: isCreator && approved
                              ? 'Post your first video or image with the + button.'
                              : 'No posts yet.',
                          icon: Icons.video_library_outlined,
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            reverse: true, // newest at the bottom, like a chat
                            padding: const EdgeInsets.only(bottom: 8, top: 8),
                            itemCount: shown.length,
                            itemBuilder: (context, i) {
                              final p = shown[i];
                              final next = i + 1 < shown.length
                                  ? shown[i + 1]
                                  : null;
                              final newDay =
                                  next == null ||
                                  !DateUtils.isSameDay(
                                    next.publishedAt,
                                    p.publishedAt,
                                  );
                              return Column(
                                children: [
                                  if (newDay) DateChip(date: p.publishedAt),
                                  PostBubble(
                                    post: p,
                                    onDelete: isCreator
                                        ? () => _deletePost(p)
                                        : null,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                ),
                if (!joined && approved)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _join,
                          child: const Text('Join'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _folderChip(String? id, String label) {
    final selected = folderId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
        onSelected: (_) => setState(() => folderId = id),
      ),
    );
  }
}

class _ReviewBanner extends StatelessWidget {
  final String status;
  const _ReviewBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final pending = status == 'pending';
    return Container(
      width: double.infinity,
      color: pending ? const Color(0xFFFFF3CD) : const Color(0xFFF8D7DA),
      padding: const EdgeInsets.all(14),
      child: Text(
        pending
            ? 'Your channel is waiting for approval. Once approved, people can find it and you can start posting.'
            : 'This channel request was not approved.',
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}
