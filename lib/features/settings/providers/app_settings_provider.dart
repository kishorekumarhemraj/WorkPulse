import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/repositories/settings_repository.dart';

const _themeModeKey = 'theme_mode';
const _quickCaptureHotKeyKey = 'quick_capture_hotkey';

class AppSettings {
  final ThemeMode themeMode;
  final HotKey quickCaptureHotKey;

  const AppSettings({
    required this.themeMode,
    required this.quickCaptureHotKey,
  });

  factory AppSettings.defaults() {
    return AppSettings(
      themeMode: ThemeMode.dark,
      quickCaptureHotKey: defaultQuickCaptureHotKey(),
    );
  }

  AppSettings copyWith({
    ThemeMode? themeMode,
    HotKey? quickCaptureHotKey,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      quickCaptureHotKey: quickCaptureHotKey ?? this.quickCaptureHotKey,
    );
  }
}

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

    return AppSettings(
      themeMode: _themeModeFromName(themeModeName),
      quickCaptureHotKey: _hotKeyFromJson(hotKeyJson),
    );
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

String hotKeyLabel(HotKey hotKey) {
  final parts = <String>[
    for (final modifier in hotKey.modifiers ?? [])
      switch (modifier) {
        HotKeyModifier.alt => '⌥',
        HotKeyModifier.control => '⌃',
        HotKeyModifier.meta => '⌘',
        HotKeyModifier.shift => '⇧',
        HotKeyModifier.fn => 'fn',
        HotKeyModifier.capsLock => '⇪',
        _ => '',
      },
    hotKey.physicalKey.keyLabel == '␣' ? 'Space' : hotKey.physicalKey.keyLabel,
  ];
  return parts.join(' ');
}
