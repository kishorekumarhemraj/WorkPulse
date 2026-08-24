import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:workpulse/core/keyboard/shortcut_labels.dart';
import 'package:workpulse/core/platform/idle_detector_service.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/repositories/settings_repository.dart';

const _themeModeKey = 'theme_mode';
const _quickCaptureHotKeyKey = 'quick_capture_hotkey';
const _idleThresholdMinutesKey = 'idle_threshold_minutes';

class AppSettings {
  final ThemeMode themeMode;
  final HotKey quickCaptureHotKey;

  /// How long the machine must go without input before WorkPulse asks what
  /// happened. Required to be configurable by `docs/WORKPULSE_SPEC.md` §31.
  final Duration idleThreshold;

  const AppSettings({
    required this.themeMode,
    required this.quickCaptureHotKey,
    required this.idleThreshold,
  });

  factory AppSettings.defaults() {
    return AppSettings(
      themeMode: ThemeMode.dark,
      quickCaptureHotKey: defaultQuickCaptureHotKey(),
      idleThreshold: DesktopIdleDetectorService.defaultIdleThreshold,
    );
  }

  AppSettings copyWith({
    ThemeMode? themeMode,
    HotKey? quickCaptureHotKey,
    Duration? idleThreshold,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      quickCaptureHotKey: quickCaptureHotKey ?? this.quickCaptureHotKey,
      idleThreshold: idleThreshold ?? this.idleThreshold,
    );
  }
}

/// The thresholds offered in the UI, in minutes. Anything shorter than a few
/// minutes would fire while a user reads their screen.
const idleThresholdOptions = <Duration>[
  Duration(minutes: 3),
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 15),
  Duration(minutes: 30),
];

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<AppSettings> build() async {
    final themeModeName = await _repo.getSetting(_themeModeKey);
    final hotKeyJson = await _repo.getSetting(_quickCaptureHotKeyKey);
    final idleMinutes = await _repo.getSetting(_idleThresholdMinutesKey);

    return AppSettings(
      themeMode: _themeModeFromName(themeModeName),
      quickCaptureHotKey: _hotKeyFromJson(hotKeyJson),
      idleThreshold: _idleThresholdFromMinutes(idleMinutes),
    );
  }

  Future<void> setIdleThreshold(Duration threshold) async {
    await _repo.setSetting(
      _idleThresholdMinutesKey,
      '${threshold.inMinutes}',
    );
    state = AsyncData((state.value ?? AppSettings.defaults()).copyWith(
      idleThreshold: threshold,
    ));
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    await _repo.setSetting(_themeModeKey, themeMode.name);
    state = AsyncData((state.value ?? AppSettings.defaults()).copyWith(
      themeMode: themeMode,
    ));
  }

  Future<void> setQuickCaptureHotKey(HotKey hotKey) async {
    final normalized = HotKey(
      key: hotKey.physicalKey,
      modifiers: hotKey.modifiers,
      scope: HotKeyScope.system,
    );
    await _repo.setSetting(
      _quickCaptureHotKeyKey,
      jsonEncode(normalized.toJson()),
    );
    state = AsyncData((state.value ?? AppSettings.defaults()).copyWith(
      quickCaptureHotKey: normalized,
    ));
  }

  ThemeMode _themeModeFromName(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  /// Falls back to the default for anything unparseable or non-positive, so a
  /// corrupted row can never disable idle detection outright.
  Duration _idleThresholdFromMinutes(String? value) {
    final minutes = int.tryParse(value ?? '');
    if (minutes == null || minutes <= 0) {
      return DesktopIdleDetectorService.defaultIdleThreshold;
    }
    return Duration(minutes: minutes);
  }

  HotKey _hotKeyFromJson(String? value) {
    if (value == null || value.isEmpty) return defaultQuickCaptureHotKey();

    try {
      return HotKey.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      return defaultQuickCaptureHotKey();
    }
  }
}

HotKey defaultQuickCaptureHotKey() {
  return HotKey(
    key: PhysicalKeyboardKey.space,
    modifiers: [HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );
}

/// Writes a hotkey the way the host platform does — `⌥ Space` on macOS,
/// `Alt+Space` on Windows. The glyphs used to be hardcoded, so a Windows user
/// was shown symbols for keys their keyboard does not have.
String hotKeyLabel(HotKey hotKey) {
  final parts = <String>[
    for (final modifier in hotKey.modifiers ?? [])
      switch (modifier) {
        HotKeyModifier.alt => ShortcutLabels.altModifier,
        HotKeyModifier.control => ShortcutLabels.controlModifier,
        HotKeyModifier.meta => ShortcutLabels.primaryModifier,
        HotKeyModifier.shift => ShortcutLabels.shiftModifier,
        HotKeyModifier.fn => 'fn',
        HotKeyModifier.capsLock =>
          ShortcutLabels.usesCommandKey ? '⇪' : 'CapsLock',
        _ => '',
      },
    hotKey.physicalKey.keyLabel == '␣' ? 'Space' : hotKey.physicalKey.keyLabel,
  ].where((part) => part.isNotEmpty).toList();

  return ShortcutLabels.usesCommandKey ? parts.join(' ') : parts.join('+');
}
