import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

abstract class WindowService {
  Future<void> initialize();
  Future<void> show();
  Future<void> hide();
  Future<void> focus();
  Future<bool> isVisible();
  Future<void> setPreventClose(bool isPreventClose);
  Future<void> minimize();
  Future<void> close();
}

class DesktopWindowService implements WindowService {
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb || (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux)) return;

    try {
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(true);
      _isInitialized = true;
    } catch (e) {
      debugPrint('DesktopWindowService initialize error: $e');
    }
  }

  @override
  Future<void> show() async {
    if (!_isInitialized) return;
    try {
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
  Future<void> setPreventClose(bool isPreventClose) async {
    if (!_isInitialized) return;
    try {
      await windowManager.setPreventClose(isPreventClose);
    } catch (e) {
      debugPrint('DesktopWindowService setPreventClose error: $e');
    }
  }

  @override
  Future<void> minimize() async {
    if (!_isInitialized) return;
    try {
      await windowManager.minimize();
    } catch (e) {
      debugPrint('DesktopWindowService minimize error: $e');
    }
  }

  @override
  Future<void> close() async {
    if (!_isInitialized) return;
    try {
      await windowManager.destroy();
    } catch (e) {
      debugPrint('DesktopWindowService close error: $e');
    }
  }
}

class NoOpWindowService implements WindowService {
  bool visible = true;
  bool focused = false;

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
  Future<void> setPreventClose(bool isPreventClose) async {}

  @override
  Future<void> minimize() async {
    visible = false;
  }

  @override
  Future<void> close() async {
    visible = false;
  }
}
