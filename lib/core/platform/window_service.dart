import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

enum WindowMode {
  dashboard,
  quickCapture,
}

abstract class WindowService {
  WindowMode get currentMode;
  ValueListenable<WindowMode> get windowModeNotifier;

  Future<void> initialize();
  Future<void> show();
  Future<void> hide();
  Future<void> focus();
  Future<bool> isVisible();
  Future<void> close();

  Future<void> openQuickCapture({double? height});
  Future<void> closeQuickCapture();
  Future<void> openDashboard();
}

class DesktopWindowService with WindowListener implements WindowService {
  static final DesktopWindowService _instance =
      DesktopWindowService._internal();
  factory DesktopWindowService() => _instance;
  DesktopWindowService._internal();

  static DesktopWindowService get instance => _instance;

  /// The HUD height when the caller does not measure one — the size Quick
  /// Capture had before its configuration bar could grow.
  static const double _defaultQuickCaptureHeight = 580;

  bool _isInitialized = false;
  WindowMode _currentMode = WindowMode.dashboard;
  final ValueNotifier<WindowMode> _modeNotifier =
      ValueNotifier<WindowMode>(WindowMode.dashboard);
  Rect? _savedDashboardBounds;
  bool _wasDashboardVisibleBeforeQuickCapture = false;

  @override
  WindowMode get currentMode => _currentMode;

  @override
  ValueListenable<WindowMode> get windowModeNotifier => _modeNotifier;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb ||
        (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux)) {
      return;
    }

    try {
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(true);
      windowManager.addListener(this);
      _isInitialized = true;
    } catch (e) {
      debugPrint('DesktopWindowService initialize error: $e');
    }
  }

  @override
  void onWindowBlur() {
    if (_currentMode == WindowMode.quickCapture) {
      closeQuickCapture();
    }
  }

  @override
  void onWindowClose() {
    hide();
  }

  @override
  Future<void> show() async {
    if (!_isInitialized) return;
    try {
      if (_currentMode == WindowMode.dashboard) {
        try {
          final size = await windowManager.getSize();
          if (size.width < 800 || size.height < 600) {
            if (_savedDashboardBounds != null) {
              await windowManager.setBounds(_savedDashboardBounds!);
            } else {
              await windowManager.setSize(const Size(1200, 800));
              await windowManager.center();
            }
          }
        } catch (_) {}
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('DesktopWindowService show error: $e');
    }
  }

  @override
  Future<void> hide() async {
    if (!_isInitialized) return;
    try {
      await windowManager.hide();
    } catch (e) {
      debugPrint('DesktopWindowService hide error: $e');
    }
  }

  @override
  Future<void> focus() async {
    if (!_isInitialized) return;
    try {
      await windowManager.focus();
    } catch (e) {
      debugPrint('DesktopWindowService focus error: $e');
    }
  }

  @override
  Future<bool> isVisible() async {
    if (!_isInitialized) return true;
    try {
      return await windowManager.isVisible();
    } catch (e) {
      debugPrint('DesktopWindowService isVisible error: $e');
      return true;
    }
  }

  @override
  Future<void> close() async {
    if (!_isInitialized) return;
    try {
      windowManager.removeListener(this);
      await windowManager.destroy();
    } catch (e) {
      debugPrint('DesktopWindowService close error: $e');
    }
  }

  @override
  Future<void> openQuickCapture({double? height}) async {
    if (kIsWeb ||
        (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux)) {
      _currentMode = WindowMode.quickCapture;
      _modeNotifier.value = WindowMode.quickCapture;
      return;
    }

    try {
      if (!_isInitialized) {
        await initialize();
      }

      final isAlreadyVisible = await windowManager.isVisible();
      _wasDashboardVisibleBeforeQuickCapture =
          _currentMode == WindowMode.dashboard && isAlreadyVisible;
      if (_wasDashboardVisibleBeforeQuickCapture) {
        try {
          _savedDashboardBounds = await windowManager.getBounds();
        } catch (_) {}
      }

      _currentMode = WindowMode.quickCapture;
      _modeNotifier.value = WindowMode.quickCapture;

      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(true);
      await windowManager.setBackgroundColor(const Color(0xFF1E1E2E));
      await windowManager.setAlwaysOnTop(true);

      const targetWidth = 640.0;
      // Sized to the fields it is about to draw. A workspace with several
      // quick-capture attributes needs a taller HUD; one with none should not
      // get the empty space. The caller measures, because the count lives in
      // a provider this service has no business reaching into.
      final targetHeight = height ?? _defaultQuickCaptureHeight;
      await windowManager.setSize(Size(targetWidth, targetHeight));

      try {
        Display? targetDisplay;
        try {
          final cursorPoint = await screenRetriever.getCursorScreenPoint();
          final displays = await screenRetriever.getAllDisplays();
          for (final display in displays) {
            final dx = display.visiblePosition?.dx ?? 0.0;
            final dy = display.visiblePosition?.dy ?? 0.0;
            final w = display.visibleSize?.width ?? display.size.width;
            final h = display.visibleSize?.height ?? display.size.height;
            if (cursorPoint.dx >= dx &&
                cursorPoint.dx <= dx + w &&
                cursorPoint.dy >= dy &&
                cursorPoint.dy <= dy + h) {
              targetDisplay = display;
              break;
            }
          }
        } catch (_) {}

        targetDisplay ??= await screenRetriever.getPrimaryDisplay();

        final screenWidth =
            targetDisplay.visibleSize?.width ?? targetDisplay.size.width;
        final screenHeight =
            targetDisplay.visibleSize?.height ?? targetDisplay.size.height;
        final screenX = targetDisplay.visiblePosition?.dx ?? 0.0;
        final screenY = targetDisplay.visiblePosition?.dy ?? 0.0;

        final x = screenX + (screenWidth - targetWidth) / 2;
        final y = screenY + (screenHeight - targetHeight) / 3;
        await windowManager.setPosition(Offset(x, y));
      } catch (e) {
        debugPrint('ScreenRetriever positioning error: $e');
        await windowManager.center();
      }

      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('DesktopWindowService openQuickCapture error: $e');
    }
  }

  @override
  Future<void> closeQuickCapture() async {
    _currentMode = WindowMode.dashboard;
    _modeNotifier.value = WindowMode.dashboard;

    if (kIsWeb ||
        (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux)) {
      return;
    }

    try {
      if (!_isInitialized) return;

      if (_wasDashboardVisibleBeforeQuickCapture) {
        await openDashboard();
      } else {
        await windowManager.hide();
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setTitleBarStyle(
          TitleBarStyle.normal,
          windowButtonVisibility: true,
        );
        if (_savedDashboardBounds != null) {
          await windowManager.setBounds(_savedDashboardBounds!);
        } else {
          await windowManager.setSize(const Size(1200, 800));
        }
      }
    } catch (e) {
      debugPrint('DesktopWindowService closeQuickCapture error: $e');
    }
  }

  @override
  Future<void> openDashboard() async {
    _currentMode = WindowMode.dashboard;
    _modeNotifier.value = WindowMode.dashboard;

    if (kIsWeb ||
        (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux)) {
      return;
    }

    try {
      if (!_isInitialized) {
        await initialize();
      }

      await windowManager.setAlwaysOnTop(false);
      await windowManager.setTitleBarStyle(
        TitleBarStyle.normal,
        windowButtonVisibility: true,
      );
      await windowManager.setBackgroundColor(const Color(0xFF1E1E2E));

      if (_savedDashboardBounds != null) {
        await windowManager.setBounds(_savedDashboardBounds!);
      } else {
        await windowManager.setSize(const Size(1200, 800));
        await windowManager.center();
      }

      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('DesktopWindowService openDashboard error: $e');
    }
  }
}

class NoOpWindowService implements WindowService {
  bool visible = true;
  bool focused = false;

  /// How many times Quick Capture has been asked to open. Tests assert this is
  /// exactly one per user gesture: opening twice used to lose the record of
  /// whether the dashboard should be restored afterwards.
  int openQuickCaptureCount = 0;

  /// The height the last open asked for, so tests can assert the HUD grows
  /// with the number of attributes rather than opening at a fixed size.
  double? lastQuickCaptureHeight;

  WindowMode _currentMode = WindowMode.dashboard;
  final ValueNotifier<WindowMode> _modeNotifier =
      ValueNotifier<WindowMode>(WindowMode.dashboard);

  @override
  WindowMode get currentMode => _currentMode;

  @override
  ValueListenable<WindowMode> get windowModeNotifier => _modeNotifier;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> show() async {
    visible = true;
    focused = true;
  }

  @override
  Future<void> hide() async {
    visible = false;
    focused = false;
  }

  @override
  Future<void> focus() async {
    focused = true;
  }

  @override
  Future<bool> isVisible() async => visible;

  @override
  Future<void> close() async {
    visible = false;
  }

  @override
  Future<void> openQuickCapture({double? height}) async {
    openQuickCaptureCount++;
    lastQuickCaptureHeight = height;
    _currentMode = WindowMode.quickCapture;
    _modeNotifier.value = WindowMode.quickCapture;
    visible = true;
    focused = true;
  }

  @override
  Future<void> closeQuickCapture() async {
    _currentMode = WindowMode.dashboard;
    _modeNotifier.value = WindowMode.dashboard;
    visible = false;
    focused = false;
  }

  @override
  Future<void> openDashboard() async {
    _currentMode = WindowMode.dashboard;
    _modeNotifier.value = WindowMode.dashboard;
    visible = true;
    focused = true;
  }
}
