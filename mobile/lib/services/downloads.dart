import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Saves a file to the phone (Android download manager → Downloads/Flixvault,
/// with a notification). On web the browser downloads it.
class Downloads {
  static const _channel = MethodChannel('cloudstorage/download');

  static Future<void> save({
    required String url,
    required String name,
    String? mime,
  }) async {
    if (kIsWeb) {
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
      return;
    }
    await _channel.invokeMethod('download', {
      'url': url,
      'name': safeName(name),
      'mime': mime,
    });
  }

  /// File-system-safe name (keeps the extension).
  static String safeName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'file' : cleaned;
  }

  /// "My video" + "posts/x/abc.mp4" → "My video.mp4".
  static String nameFor(String title, String key) {
    final dot = key.lastIndexOf('.');
    final ext = dot > key.lastIndexOf('/') && dot >= 0
        ? key.substring(dot)
        : '';
    return '${title.trim().isEmpty ? 'Flixvault' : title.trim()}$ext';
  }
}
