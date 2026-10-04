import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Screen rotation for the video player (Android). "follow" turns the screen
/// with the phone's tilt like MX Player / VLC, even when auto-rotate is off;
/// "reset" hands control back to the phone's own setting.
class ScreenRotation {
  static const _channel = MethodChannel('cloudstorage/screen');

  static Future<void> follow() => _call('sensor');
  static Future<void> landscape() => _call('landscape');
  static Future<void> portrait() => _call('portrait');
  static Future<void> reset() => _call('reset');

  static Future<void> _call(String method) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {
      // Rotation is a nicety; playback must never fail because of it.
    }
  }
}
