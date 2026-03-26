import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  static const _channel = MethodChannel('ghost_chat/overlay');
  static bool _isOverlayContext = false;

  // ✅ Call this from overlayMain context to mark we're inside overlay
  static void markAsOverlayContext() {
    _isOverlayContext = true;
  }

  static Future<bool> requestPermission() async {
    final already = await FlutterOverlayWindow.isPermissionGranted();
    if (!already) {
      final granted = await FlutterOverlayWindow.requestPermission();
      return granted ?? false;
    }
    return true;
  }

  static Future<void> showGhostChat() async {
    debugPrint('👻 showGhostChat() called');

    // ✅ If already inside overlay, don't try to launch again
    if (_isOverlayContext) {
      debugPrint('⚠️ Already in overlay context — skipping');
      return;
    }

    final hasPermission = await requestPermission();
    debugPrint('🔑 Has permission: $hasPermission');
    if (!hasPermission) return;

    try {
      await _channel.invokeMethod('launchOverlay');
      debugPrint('✅ launchOverlay invoked');
    } catch (e) {
      debugPrint('❌ Channel error: $e');
    }
  }

  static Future<void> closeGhostChat() async {
    try {
      await _channel.invokeMethod('closeOverlay');
    } catch (_) {}
  }

  static Future<bool> get isActive => FlutterOverlayWindow.isActive();
}
