import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  static Future<void> requestPermission() async {
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      await FlutterOverlayWindow.requestPermission();
    }
  }

  static Future<void> showGhostChat() async {
    await requestPermission();
    await FlutterOverlayWindow.showOverlay(
      enableDrag: false,
      overlayTitle: "Ghost Chat",
      overlayContent: '',
      flag: OverlayFlag.defaultFlag,
      visibility:
          NotificationVisibility.visibilitySecret, // hide from notifications
      positionGravity: PositionGravity.none,
      width: WindowSize.matchParent,
      height: WindowSize.matchParent,
    );
  }

  static Future<void> closeGhostChat() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  static Future<bool> get isActive => FlutterOverlayWindow.isActive();
}
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  static Future<bool> showGhostChat() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    final hasPermission =
        await FlutterOverlayWindow.isPermissionGranted() ?? false;
    if (!hasPermission) {
      final granted = await FlutterOverlayWindow.requestPermission();
      if (!granted) {
        return false;
      }
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'Ghost Chat',
      overlayContent: 'Tap to open',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: WindowSize.matchParent,
      width: WindowSize.matchParent,
      startPosition: const OverlayPosition(0, 0),
    );

    return true;
  }

  static Future<void> closeGhostChat() {
    return FlutterOverlayWindow.closeOverlay();
  }
}
