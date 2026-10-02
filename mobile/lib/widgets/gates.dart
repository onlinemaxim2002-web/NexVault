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
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => LoginScreen(reason: reason)),
  );
  return ok == true && !app.isGuest;
}

Future<void> openPlans(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen(standalone: true)));
}

/// Watch a post item: login → plan (for premium items) → online player.
Future<void> watchItem(BuildContext context, Post post, PostItem item) async {
  if (!await ensureLoggedIn(context, reason: 'Log in to watch')) return;
  if (!context.mounted) return;
  if (item.isPremium && !app.isPremium) {
    await openPlans(context);
    return;
  }
  try {
    final url = await Backend.mediaUrl(item.mediaKey);
    Backend.logEvent(app.installId, 'content_view', contentId: post.id, viewId: const Uuid().v4());
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => item.isVideo ? PlayerScreen(url: url, title: post.title) : ImageViewerScreen(url: url, title: post.title),
    ));
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyError(e));
  }
}
