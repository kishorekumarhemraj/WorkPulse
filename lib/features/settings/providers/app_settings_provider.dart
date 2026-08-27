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
const _timesheetWeekStartDayKey = 'timesheet_week_start_day';
const _timesheetRoundingIncrementKey = 'timesheet_rounding_increment';

class AppSettings {
  final ThemeMode themeMode;
  final HotKey quickCaptureHotKey;

  /// How long the machine must go without input before WorkPulse asks what
  /// happened. Required to be configurable by `docs/WORKPULSE_SPEC.md` §31.
  final Duration idleThreshold;

  /// The first day of the week on the timesheet grid (1 = Monday, 7 = Sunday).
  /// Defaults to Saturday (6) to match standard timesheet cycles.
  final int timesheetWeekStartDay;

  /// Rounding granularity for timesheet grid cells (0.01, 0.05, 0.25, 0.50).
  /// Defaults to 0.25 (quarter-hour).
  final double timesheetRoundingIncrement;

  static const defaultTimesheetWeekStartDay = DateTime.saturday;
  static const defaultTimesheetRoundingIncrement = 0.25;

  const AppSettings({
    required this.themeMode,
    required this.quickCaptureHotKey,
    required this.idleThreshold,
    this.timesheetWeekStartDay = defaultTimesheetWeekStartDay,
    this.timesheetRoundingIncrement = defaultTimesheetRoundingIncrement,
  });

  factory AppSettings.defaults() {
    return AppSettings(
      themeMode: ThemeMode.dark,
      quickCaptureHotKey: defaultQuickCaptureHotKey(),
      idleThreshold: DesktopIdleDetectorService.defaultIdleThreshold,
      timesheetWeekStartDay: defaultTimesheetWeekStartDay,
      timesheetRoundingIncrement: defaultTimesheetRoundingIncrement,
    );
  }

  AppSettings copyWith({
    ThemeMode? themeMode,
    HotKey? quickCaptureHotKey,
    Duration? idleThreshold,
    int? timesheetWeekStartDay,
    double? timesheetRoundingIncrement,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      quickCaptureHotKey: quickCaptureHotKey ?? this.quickCaptureHotKey,
      idleThreshold: idleThreshold ?? this.idleThreshold,
      timesheetWeekStartDay:
          timesheetWeekStartDay ?? this.timesheetWeekStartDay,
      timesheetRoundingIncrement:
          timesheetRoundingIncrement ?? this.timesheetRoundingIncrement,
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

const timesheetWeekStartDayOptions = <int>[
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
  DateTime.sunday,
];

const timesheetRoundingIncrementOptions = <double>[
  0.01,
  0.05,
  0.25,
  0.50,
];

String weekdayName(int weekday) => switch (weekday) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => 'Unknown',
    };

String roundingIncrementLabel(double increment) => switch (increment) {
      0.01 => '0.01 h (exact to hundredth)',
      0.05 => '0.05 h (3 min)',
      0.25 => '0.25 h (15 min / quarter-hour)',
      0.50 => '0.50 h (30 min / half-hour)',
      _ => '${increment.toStringAsFixed(2)} h',
    };

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
    final weekStartDayStr = await _repo.getSetting(_timesheetWeekStartDayKey);
    final roundingIncrementStr =
        await _repo.getSetting(_timesheetRoundingIncrementKey);

    return AppSettings(
      themeMode: _themeModeFromName(themeModeName),
      quickCaptureHotKey: _hotKeyFromJson(hotKeyJson),
      idleThreshold: _idleThresholdFromMinutes(idleMinutes),
      timesheetWeekStartDay: _weekStartDayFromValue(weekStartDayStr),
      timesheetRoundingIncrement:
          _roundingIncrementFromValue(roundingIncrementStr),
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

  Future<void> setTimesheetWeekStartDay(int day) async {
    await _repo.setSetting(
      _timesheetWeekStartDayKey,
      '$day',
    );
    state = AsyncData((state.value ?? AppSettings.defaults()).copyWith(
      timesheetWeekStartDay: day,
    ));
  }

  Future<void> setTimesheetRoundingIncrement(double increment) async {
    await _repo.setSetting(
      _timesheetRoundingIncrementKey,
      '$increment',
    );
    state = AsyncData((state.value ?? AppSettings.defaults()).copyWith(
      timesheetRoundingIncrement: increment,
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

  int _weekStartDayFromValue(String? value) {
    final day = int.tryParse(value ?? '');
    if (day == null || day < DateTime.monday || day > DateTime.sunday) {
      return AppSettings.defaultTimesheetWeekStartDay;
    }
    return day;
  }

  double _roundingIncrementFromValue(String? value) {
    final increment = double.tryParse(value ?? '');
    if (increment == null ||
        !timesheetRoundingIncrementOptions.contains(increment)) {
      return AppSettings.defaultTimesheetRoundingIncrement;
    }
    return increment;
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
