import 'package:flutter/foundation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:workpulse/features/settings/providers/app_settings_provider.dart';

abstract class HotKeyService {
  Future<void> initialize();
  Future<void> registerQuickCaptureHotKey(
    VoidCallback onTrigger, {
    HotKey? hotKey,
  });
  Future<void> unregisterAll();
}

class DesktopHotKeyService implements HotKeyService {
  HotKey? _quickCaptureHotKey;

  @override
  Future<void> initialize() async {
    try {
      // HotKeyManager is only available on desktop platforms
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux)) {
        await hotKeyManager.unregisterAll();
      }
    } catch (e) {
      debugPrint('HotKeyService initialize error: $e');
    }
  }

  @override
  Future<void> registerQuickCaptureHotKey(
    VoidCallback onTrigger, {
    HotKey? hotKey,
  }) async {
    try {
      if (kIsWeb ||
          (defaultTargetPlatform != TargetPlatform.macOS &&
              defaultTargetPlatform != TargetPlatform.windows &&
              defaultTargetPlatform != TargetPlatform.linux)) {
        return;
      }

      if (_quickCaptureHotKey != null) {
        await hotKeyManager.unregister(_quickCaptureHotKey!);
      }

      _quickCaptureHotKey = hotKey ?? defaultQuickCaptureHotKey();

      await hotKeyManager.register(
        _quickCaptureHotKey!,
        keyDownHandler: (_) => onTrigger(),
      );
    } catch (e) {
      debugPrint('Failed to register Quick Capture hotkey: $e');
    }
  }

  @override
  Future<void> unregisterAll() async {
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux)) {
        await hotKeyManager.unregisterAll();
      }
    } catch (e) {
      debugPrint('Failed to unregister hotkeys: $e');
    }
  }
}

/// A [HotKeyService] that records what it was asked to do without touching the
/// OS.
///
/// The platform-bridges rule has always specified one of these alongside
/// [NoOpTrayService] and [NoOpWindowService]; only the hotkey half was missing,
/// so tests either reached the real `hotKeyManager` or hand-rolled a stub.
class NoOpHotKeyService implements HotKeyService {
  bool isInitialized = false;

  /// The hotkey currently registered, or null once unregistered.
  HotKey? registeredHotKey;

  /// The callback the registered hotkey would invoke. Call it to simulate the
  /// user pressing the shortcut.
  VoidCallback? onTrigger;

  int registerCount = 0;
  int unregisterAllCount = 0;

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

  @override
  Future<void> registerQuickCaptureHotKey(
    VoidCallback onTrigger, {
    HotKey? hotKey,
  }) async {
    registerCount++;
    this.onTrigger = onTrigger;
    registeredHotKey = hotKey ?? defaultQuickCaptureHotKey();
  }

  @override
  Future<void> unregisterAll() async {
    unregisterAllCount++;
    registeredHotKey = null;
    onTrigger = null;
  }
}
