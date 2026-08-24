import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:workpulse/core/keyboard/shortcut_labels.dart';
import 'package:workpulse/features/settings/providers/app_settings_provider.dart';

void main() {
  // Every shortcut hint used to be spelled with macOS glyphs regardless of
  // host, so Windows users were shown symbols for keys they do not have —
  // while it was the Ctrl binding that actually fired.
  group('ShortcutLabels', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    void onPlatform(TargetPlatform platform, void Function() body) {
      debugDefaultTargetPlatformOverride = platform;
      try {
        body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    test('macOS uses Command glyphs run together', () {
      onPlatform(TargetPlatform.macOS, () {
        expect(ShortcutLabels.usesCommandKey, isTrue);
        expect(ShortcutLabels.primary('N'), '⌘N');
        expect(ShortcutLabels.alt('Space'), '⌥Space');
        expect(ShortcutLabels.submitKeys, ['⌘', '↩']);
        expect(ShortcutLabels.platformName, 'macOS');
        expect(ShortcutLabels.revealActionLabel, 'Show in Finder');
      });
    });

    test('Windows uses Ctrl names joined with a plus', () {
      onPlatform(TargetPlatform.windows, () {
        expect(ShortcutLabels.usesCommandKey, isFalse);
        expect(ShortcutLabels.primary('N'), 'Ctrl+N');
        expect(ShortcutLabels.alt('Space'), 'Alt+Space');
        expect(ShortcutLabels.submitKeys, ['Ctrl', 'Enter']);
        expect(ShortcutLabels.platformName, 'Windows');
        expect(ShortcutLabels.revealActionLabel, 'Show in File Explorer');
      });
    });

    test('Linux is named and falls back to Ctrl conventions', () {
      onPlatform(TargetPlatform.linux, () {
        expect(ShortcutLabels.primary('E'), 'Ctrl+E');
        expect(ShortcutLabels.platformName, 'Linux');
        expect(ShortcutLabels.revealActionLabel, 'Show in file manager');
      });
    });
  });

  group('hotKeyLabel', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    final hotKey = HotKey(
      key: PhysicalKeyboardKey.space,
      modifiers: [HotKeyModifier.alt],
      scope: HotKeyScope.system,
    );

    test('reads as a macOS chord on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(hotKeyLabel(hotKey), '⌥ Space');
    });

    test('reads as a Windows chord on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(hotKeyLabel(hotKey), 'Alt+Space');
    });

    test('renders multi-modifier chords on both platforms', () {
      final chord = HotKey(
        key: PhysicalKeyboardKey.keyK,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(hotKeyLabel(chord), '⌘ ⇧ K');

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(hotKeyLabel(chord), 'Ctrl+Shift+K');
    });
  });
}
