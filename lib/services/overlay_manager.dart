import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'analytics_service.dart';

class OverlayManager {
  OverlayManager._();

  static const _tag = 'OverlayManager';

  /// Orb idle window size (10dp orb + touch padding for easy drag)
  static const idleWindowSize = 44;

  /// Radial menu window size (76dp radius × 2 + 30dp icons + 30dp margin)
  static const menuWindowSize = 240;

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  static Future<bool> hasOverlayPermission() {
    return FlutterOverlayWindow.isPermissionGranted();
  }

  static Future<bool> requestOverlayPermission() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    AnalyticsService.instance.info(_tag, 'Check overlay permission',
        properties: {'granted': granted});
    if (granted) return true;
    AnalyticsService.instance.trackEvent('permission_requested');
    final result = await FlutterOverlayWindow.requestPermission();
    AnalyticsService.instance.trackEvent('permission_result',
        properties: {'granted': result ?? false});
    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  static Future<bool> isOverlayActive() {
    return FlutterOverlayWindow.isActive();
  }

  /// Show the orb overlay. Safe to call when already active.
  static Future<void> showOrb() async {
    final active = await FlutterOverlayWindow.isActive();
    if (active) {
      AnalyticsService.instance.debug(_tag, 'Orb already active, skip');
      return;
    }

    AnalyticsService.instance.trackEvent('orb_show');
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'Float',
      overlayContent: '捕球运行中 · 点悬浮球捕获想法',
      alignment: OverlayAlignment.centerRight,
      height: idleWindowSize,
      width: idleWindowSize,
      flag: OverlayFlag.defaultFlag,
      positionGravity: PositionGravity.auto,
      visibility: NotificationVisibility.visibilityPublic,
    );
  }

  /// Stop the overlay entirely.
  static Future<void> closeOverlay() async {
    AnalyticsService.instance.trackEvent('orb_close');
    await FlutterOverlayWindow.closeOverlay();
  }

  // ---------------------------------------------------------------------------
  // Window sizing (called from overlay isolate)
  // ---------------------------------------------------------------------------

  /// Resize to idle dot (48dp), re-enable native drag.
  static Future<void> setOrbIdle() async {
    await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
    await FlutterOverlayWindow.resizeOverlay(
      idleWindowSize, idleWindowSize, true,
    );
  }

  /// Resize to menu area (260dp), disable native drag so Flutter handles
  /// swipe-direction selection.
  static Future<void> setOrbMenuSize() async {
    await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
    await FlutterOverlayWindow.resizeOverlay(
      menuWindowSize, menuWindowSize, false,
    );
  }

  /// Compact floating panel — draggable, keyboard-friendly.
  static Future<void> setOrbCaptureMode() async {
    await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
    await FlutterOverlayWindow.resizeOverlay(
      300, 200, true, // compact draggable window
    );
  }

  /// Voice capture floating panel — taller for transcription display.
  static Future<void> setOrbVoiceMode() async {
    await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
    await FlutterOverlayWindow.resizeOverlay(300, 250, true);
  }

  // ---------------------------------------------------------------------------
  // Misc
  // ---------------------------------------------------------------------------

  static Future<bool> openAppSettings() {
    AnalyticsService.instance.trackEvent('open_app_settings');
    return ph.openAppSettings();
  }
}
