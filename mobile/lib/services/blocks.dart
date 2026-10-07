import 'package:shared_preferences/shared_preferences.dart';

/// Channels this user blocked (kept on the phone). Their posts are hidden from
/// Explore, Feed and channel lists.
class Blocks {
  static const _key = 'blocked_channels';
  static Set<String> _ids = {};

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ids = (prefs.getStringList(_key) ?? const []).toSet();
  }

  static bool has(String channelId) => _ids.contains(channelId);

  static Future<void> set(String channelId, bool blocked) async {
    blocked ? _ids.add(channelId) : _ids.remove(channelId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids.toList());
  }
}
