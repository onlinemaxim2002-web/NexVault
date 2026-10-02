import 'package:flutter/material.dart';

import '../models.dart';
import '../services/backend.dart';
import '../widgets/common.dart';
import '../widgets/reload.dart';
import 'post_screen.dart';

/// Explore: every visible post from all channels, as a 3-column grid.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const tabs = [
    ('all', 'All'),
    ('latest', 'Latest'),
    ('popular', 'Popular'),
    ('most_watched', 'Most watched'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Explore'),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'About Explore',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Explore'),
                  content: const Text(
                    'Discover posts from all channels. Tap a post to watch it.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
            ),
            const CrownButton(),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            tabs: [for (final t in tabs) Tab(text: t.$2)],
          ),
        ),
        body: TabBarView(
          children: [for (final t in tabs) _ExploreGrid(tab: t.$1)],
        ),
      ),
    );
  }
}

class _ExploreGrid extends StatefulWidget {
  final String tab;
  const _ExploreGrid({required this.tab});

  @override
  State<_ExploreGrid> createState() => _ExploreGridState();
}

class _ExploreGridState extends State<_ExploreGrid>
    with ContentReload, AutomaticKeepAliveClientMixin {
  List<Post>? posts;
  String? error;
  bool loadingMore = false;
  bool done = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> reload() async {
    try {
      final list = await Backend.explore(widget.tab);
      if (!mounted) return;
      setState(() {
        posts = list;
        error = null;
        done = list.length < 30;
      });
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
  }

  Future<void> _more() async {
    if (loadingMore || done || posts == null) return;
    loadingMore = true;
    try {
      final list = await Backend.explore(widget.tab, offset: posts!.length);
      if (mounted) {
        setState(() {
          posts = [...posts!, ...list];
          done = list.length < 30;
        });
      }
    } finally {
      loadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (error != null && posts == null) {
      return ErrorRetry(message: error!, onRetry: reload);
    }
    if (posts == null) return const Center(child: CircularProgressIndicator());
    if (posts!.isEmpty) {
      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            EmptyState(
              message: 'Nothing here yet.\nNew posts from channels will show up here.',
              icon: Icons.explore_outlined,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: reload,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _more();
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 0.75,
          ),
          itemCount: posts!.length,
          itemBuilder: (context, i) => _Tile(post: posts![i]),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Post post;
  const _Tile({required this.post});

  @override
  Widget build(BuildContext context) {
    final cover = post.cover;
    return Semantics(
      label: post.title,
      button: true,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostScreen(postId: post.id, initial: post),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetThumb(
              url: cover?.thumbUrl,
              fallback: cover?.isVideo == true
                  ? Icons.videocam_outlined
                  : Icons.image_outlined,
            ),
            if (cover?.isVideo == true)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 30,
                  shadows: [Shadow(blurRadius: 6)],
                ),
              ),
            if (post.hasPremium)
              const Positioned(top: 6, left: 6, child: PremiumBadge()),
            if (post.items.length > 1)
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${post.items.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
