import 'package:flutter/material.dart';

import '../models.dart';
import '../services/backend.dart';
import '../widgets/common.dart';
import '../widgets/reload.dart';
import '../theme.dart';
import 'post_screen.dart';

/// Explore: every visible post from all channels, as a grid of media cards.
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
          flexibleSpace: const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.barGradient),
            child: SizedBox.expand(),
          ),
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.muted,
                indicatorSize: TabBarIndicatorSize.tab,
                splashBorderRadius: BorderRadius.circular(20),
                indicator: BoxDecoration(
                  gradient: AppColors.gradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                tabs: [
                  for (final t in tabs)
                    Tab(
                      height: 36,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(t.$2),
                      ),
                    ),
                ],
              ),
            ),
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
        child: LayoutBuilder(
          builder: (context, box) {
            // 2 columns on phones, more on tablets; 16:9 thumbs + title.
            final cols = (box.maxWidth / 230).floor().clamp(2, 5);
            final cardW = (box.maxWidth - 12 * (cols + 1)) / cols;
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                mainAxisExtent: cardW * 9 / 16 + 66,
              ),
              itemCount: posts!.length,
              itemBuilder: (context, i) => _Tile(post: posts![i]),
            );
          },
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
    final duration = cover?.durationS;
    return Semantics(
      label: post.title,
      button: true,
      child: PressScale(
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostScreen(postId: post.id, initial: post),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.card),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x80000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.card),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        NetThumb(
                          url: cover?.thumbUrl,
                          fallback: cover?.isVideo == true
                              ? Icons.movie_outlined
                              : Icons.image_outlined,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(gradient: AppColors.scrim),
                        ),
                        if (cover?.isVideo == true)
                          const Center(child: PlayOverlay(size: 38)),
                        if (post.hasPremium)
                          const Positioned(
                            top: 8,
                            left: 8,
                            child: PremiumBadge(),
                          ),
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (post.items.length > 1)
                                ThumbPill(
                                  '${post.items.length}',
                                  icon: Icons.collections_outlined,
                                ),
                              if (post.items.length > 1 &&
                                  duration != null &&
                                  duration > 0)
                                const SizedBox(width: 4),
                              if (duration != null && duration > 0)
                                ThumbPill(formatDuration(duration)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
                child: Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
                child: Text(
                  '${post.channelName} · ${timeAgo(post.publishedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
