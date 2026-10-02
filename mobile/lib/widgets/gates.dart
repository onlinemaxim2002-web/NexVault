import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../screens/login_screen.dart';
import '../screens/player_screen.dart';
import '../screens/premium_screen.dart';
import '../services/backend.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Login gate: guests are sent to log in / create an account.
Future<bool> ensureLoggedIn(BuildContext context, {String? reason}) async {
  if (!app.isGuest) return true;
  final ok = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => LoginScreen(reason: reason)));
  return ok == true && !app.isGuest;
}

Future<void> openPlans(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const PremiumScreen(standalone: true)),
  );
}

/// The creator always sees their own content in full; otherwise premium
/// items need a plan.
bool canWatchFull(Post post, PostItem item) {
  final mine = post.createdBy != null && post.createdBy == app.userId;
  return mine || !item.isPremium || app.isPremium;
}

/// Ads users can play a premium item's trailer without login or plan.
bool canWatchTrailer(Post post, PostItem item) =>
    item.hasTrailer && !canWatchFull(post, item) && app.hasAdsAccess;

/// Watch a post item: login → plan (for premium items) → online player.
Future<void> watchItem(BuildContext context, Post post, PostItem item) async {
  final mine = post.createdBy != null && post.createdBy == app.userId;
  if (!mine && !await ensureLoggedIn(context, reason: 'Log in to watch')) {
    return;
  }
  if (!context.mounted) return;
  if (!canWatchFull(post, item)) {
    await openPlans(context);
    return;
  }
  await _play(context, post, item.mediaKey, item.isVideo, post.title);
}

/// Play the trailer; the player offers "Watch full video" (login → plan).
Future<void> watchTrailer(
  BuildContext context,
  Post post,
  PostItem item,
) async {
  await _play(
    context,
    post,
    item.trailerKey!,
    true,
    'Trailer · ${post.title}',
    onWatchFull: (ctx) => watchItem(ctx, post, item),
  );
}

/// Tap on a post's media: trailer when that's all the user may watch,
/// otherwise the full item (with its gates).
Future<void> openItem(BuildContext context, Post post, PostItem item) =>
    canWatchTrailer(post, item)
    ? watchTrailer(context, post, item)
    : watchItem(context, post, item);

Future<void> _play(
  BuildContext context,
  Post post,
  String key,
  bool isVideo,
  String title, {
  void Function(BuildContext)? onWatchFull,
}) async {
  try {
    final url = await Backend.mediaUrl(key);
    Backend.logEvent(
      app.installId,
      onWatchFull == null ? 'content_view' : 'preview_view',
      contentId: post.id,
      viewId: const Uuid().v4(),
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isVideo
            ? PlayerScreen(url: url, title: title, onWatchFull: onWatchFull)
            : ImageViewerScreen(url: url, title: title),
      ),
    );
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyError(e));
  }
}
