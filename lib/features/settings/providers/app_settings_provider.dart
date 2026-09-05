import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:workpulse/core/keyboard/shortcut_labels.dart';
import 'package:workpulse/core/platform/idle_detector_service.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/reminder_rule.dart';
import 'package:workpulse/domain/repositories/settings_repository.dart';

export 'package:workpulse/domain/models/reminder_rule.dart';

const _themeModeKey = 'theme_mode';
const _quickCaptureHotKeyKey = 'quick_capture_hotkey';
const _idleThresholdMinutesKey = 'idle_threshold_minutes';
const _timesheetWeekStartDayKey = 'timesheet_week_start_day';
const _timesheetRoundingIncrementKey = 'timesheet_rounding_increment';
const _enabledReminderRulesKey = 'enabled_reminder_rules';
const _dailyDigestTimeKey = 'daily_digest_time';
const _dueReminderLeadTimeMinutesKey = 'due_reminder_lead_time_minutes';
const _quietHoursStartKey = 'quiet_hours_start';
const _quietHoursEndKey = 'quiet_hours_end';
const _weekendRemindersKey = 'weekend_reminders';
const _snoozeDefaultMinutesKey = 'snooze_default_minutes';

class AppSettings {
  final ThemeMode themeMode;
  final HotKey quickCaptureHotKey;

  /// How long the machine must go without input before WorkPulse asks what
  /// happened. Required to be configurable by `docs/WORKPULSE_SPEC.md` §31.
  final Duration idleThreshold;

  /// The first day of the week on the timesheet grid (1 = Monday, 7 = Sunday).
  /// Defaults to Sunday (7) to match dashboard cycles.
  final int timesheetWeekStartDay;

  /// Rounding granularity for timesheet grid cells (0.01, 0.05, 0.25, 0.50).
  /// Defaults to 0.25 (quarter-hour).
  final double timesheetRoundingIncrement;

  /// Enabled reminder notification rules.
  final Set<ReminderRule> enabledReminderRules;

  /// Time of day when daily digest / morning reminders fire.
  final TimeOfDay dailyDigestTime;

  /// Lead time before due date/time to send reminder.
  final Duration dueReminderLeadTime;

  /// Quiet hours start time (e.g. 20:00).
  final TimeOfDay? quietHoursStart;

  /// Quiet hours end time (e.g. 08:00).
  final TimeOfDay? quietHoursEnd;

  /// Whether reminders are allowed to deliver on weekends (Saturday & Sunday).
  final bool weekendReminders;

  /// Default snooze duration.
  final Duration snoozeDefault;

  static const defaultTimesheetWeekStartDay = DateTime.sunday;
  static const defaultTimesheetRoundingIncrement = 0.25;
  static const defaultDailyDigestTime = TimeOfDay(hour: 9, minute: 0);
  static const defaultDueReminderLeadTime = Duration(hours: 1);
  static const defaultSnoozeDefault = Duration(hours: 1);

  const AppSettings({
    required this.themeMode,
    required this.quickCaptureHotKey,
    required this.idleThreshold,
    this.timesheetWeekStartDay = defaultTimesheetWeekStartDay,
    this.timesheetRoundingIncrement = defaultTimesheetRoundingIncrement,
    this.enabledReminderRules = const {
      ReminderRule.dueMorning,
      ReminderRule.due1h,
      ReminderRule.overdueDaily,
      ReminderRule.startMorning,
    },
    this.dailyDigestTime = defaultDailyDigestTime,
    this.dueReminderLeadTime = defaultDueReminderLeadTime,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.weekendReminders = false,
    this.snoozeDefault = defaultSnoozeDefault,
  });

  factory AppSettings.defaults() {
    return AppSettings(
      themeMode: ThemeMode.dark,
      quickCaptureHotKey: defaultQuickCaptureHotKey(),
      idleThreshold: DesktopIdleDetectorService.defaultIdleThreshold,
      timesheetWeekStartDay: defaultTimesheetWeekStartDay,
      timesheetRoundingIncrement: defaultTimesheetRoundingIncrement,
      enabledReminderRules: ReminderRule.values.toSet(),
      dailyDigestTime: defaultDailyDigestTime,
      dueReminderLeadTime: defaultDueReminderLeadTime,
      quietHoursStart: null,
      quietHoursEnd: null,
      weekendReminders: false,
      snoozeDefault: defaultSnoozeDefault,
    );
  }

  AppSettings copyWith({
    ThemeMode? themeMode,
    HotKey? quickCaptureHotKey,
    Duration? idleThreshold,
    int? timesheetWeekStartDay,
    double? timesheetRoundingIncrement,
    Set<ReminderRule>? enabledReminderRules,
    TimeOfDay? dailyDigestTime,
    Duration? dueReminderLeadTime,
    TimeOfDay? quietHoursStart,
    bool clearQuietHoursStart = false,
    TimeOfDay? quietHoursEnd,
    bool clearQuietHoursEnd = false,
    bool? weekendReminders,
    Duration? snoozeDefault,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      quickCaptureHotKey: quickCaptureHotKey ?? this.quickCaptureHotKey,
      idleThreshold: idleThreshold ?? this.idleThreshold,
      timesheetWeekStartDay:
          timesheetWeekStartDay ?? this.timesheetWeekStartDay,
      timesheetRoundingIncrement:
          timesheetRoundingIncrement ?? this.timesheetRoundingIncrement,
      enabledReminderRules: enabledReminderRules ?? this.enabledReminderRules,
      dailyDigestTime: dailyDigestTime ?? this.dailyDigestTime,
      dueReminderLeadTime: dueReminderLeadTime ?? this.dueReminderLeadTime,
      quietHoursStart: clearQuietHoursStart
          ? null
          : (quietHoursStart ?? this.quietHoursStart),
      quietHoursEnd:
          clearQuietHoursEnd ? null : (quietHoursEnd ?? this.quietHoursEnd),
      weekendReminders: weekendReminders ?? this.weekendReminders,
      snoozeDefault: snoozeDefault ?? this.snoozeDefault,
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
    final reminderRulesJson =
        await _repo.getSetting(_enabledReminderRulesKey);
    final dailyDigestStr = await _repo.getSetting(_dailyDigestTimeKey);
    final leadTimeMinutesStr =
        await _repo.getSetting(_dueReminderLeadTimeMinutesKey);
    final quietStartStr = await _repo.getSetting(_quietHoursStartKey);
    final quietEndStr = await _repo.getSetting(_quietHoursEndKey);
    final weekendRemindersStr =
        await _repo.getSetting(_weekendRemindersKey);
    final snoozeDefaultMinutesStr =
        await _repo.getSetting(_snoozeDefaultMinutesKey);

    return AppSettings(
      themeMode: _themeModeFromName(themeModeName),
      quickCaptureHotKey: _hotKeyFromJson(hotKeyJson),
      idleThreshold: _idleThresholdFromMinutes(idleMinutes),
      timesheetWeekStartDay: _weekStartDayFromValue(weekStartDayStr),
      timesheetRoundingIncrement:
          _roundingIncrementFromValue(roundingIncrementStr),
      enabledReminderRules: _reminderRulesFromJson(reminderRulesJson),
      dailyDigestTime: _timeOfDayFromJson(
          dailyDigestStr, AppSettings.defaultDailyDigestTime),
      dueReminderLeadTime: _durationFromMinutes(
          leadTimeMinutesStr, AppSettings.defaultDueReminderLeadTime),
      quietHoursStart: _timeOfDayNullableFromJson(quietStartStr),
      quietHoursEnd: _timeOfDayNullableFromJson(quietEndStr),
      weekendReminders: weekendRemindersStr == 'true',
      snoozeDefault: _durationFromMinutes(
          snoozeDefaultMinutesStr, AppSettings.defaultSnoozeDefault),
    );
  }

  Future<void> setReminderRule(ReminderRule rule, bool enabled) async {
    final current = state.value ?? AppSettings.defaults();
    final updated = Set<ReminderRule>.from(current.enabledReminderRules);
    if (enabled) {
      updated.add(rule);
    } else {
      updated.remove(rule);
    }
    await _repo.setSetting(
      _enabledReminderRulesKey,
      jsonEncode(updated.map((r) => r.name).toList()),
    );
    state = AsyncData(current.copyWith(enabledReminderRules: updated));
  }

  Future<void> setDailyDigestTime(TimeOfDay time) async {
    await _repo.setSetting(_dailyDigestTimeKey, _timeOfDayToJson(time)!);
    state = AsyncData((state.value ?? AppSettings.defaults()).copyWith(
      dailyDigestTime: time,
    ));
  }

  Future<void> setDueReminderLeadTime(Duration duration) async {
    await _repo.setSetting(
      _dueReminderLeadTimeMinutesKey,
      '${duration.inMinutes}',
    );
    state = AsyncData((state.value ?? AppSettings.defaults()).copyWith(
      dueReminderLeadTime: duration,
    ));
  }

  Future<void> setQuietHours({TimeOfDay? start, TimeOfDay? end}) async {
    if (start != null) {
      await _repo.setSetting(_quietHoursStartKey, _timeOfDayToJson(start)!);
    } else {
      await _repo.setSetting(_quietHoursStartKey, '');
    }
    if (end != null) {
      await _repo.setSetting(_quietHoursEndKey, _timeOfDayToJson(end)!);
    } else {
      await _repo.setSetting(_quietHoursEndKey, '');
    }
    state = AsyncData((state.value ?? AppSettings.defaults()).copyWith(
      quietHoursStart: start,
      clearQuietHoursStart: start == null,
      quietHoursEnd: end,
      clearQuietHoursEnd: end == null,
    ));
  }

  Future<void> setWeekendReminders(bool enabled) async {
    await _repo.setSetting(_weekendRemindersKey, '$enabled');
    state = AsyncData((state.value ?? AppSettings.defaults()).copyWith(
      weekendReminders: enabled,
    ));
  }

  Future<void> setSnoozeDefault(Duration duration) async {
    await _repo.setSetting(
      _snoozeDefaultMinutesKey,
      '${duration.inMinutes}',
    );
    state = AsyncData((state.value ?? AppSettings.defaults()).copyWith(
      snoozeDefault: duration,
    ));
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

  Duration _durationFromMinutes(String? value, Duration fallback) {
    final minutes = int.tryParse(value ?? '');
    if (minutes == null || minutes <= 0) {
      return fallback;
    }
    return Duration(minutes: minutes);
  }

  Set<ReminderRule> _reminderRulesFromJson(String? value) {
    if (value == null || value.isEmpty) {
      return ReminderRule.values.toSet();
    }
    try {
      final list = jsonDecode(value) as List<dynamic>;
      final set = <ReminderRule>{};
      for (final item in list) {
        for (final rule in ReminderRule.values) {
          if (rule.name == item) {
            set.add(rule);
          }
        }
      }
      return set;
    } catch (_) {
      return ReminderRule.values.toSet();
    }
  }

  TimeOfDay _timeOfDayFromJson(String? value, TimeOfDay fallback) {
    if (value == null || !value.contains(':')) return fallback;
    try {
      final parts = value.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return TimeOfDay(hour: h, minute: m);
    } catch (_) {
      return fallback;
    }
  }

  TimeOfDay? _timeOfDayNullableFromJson(String? value) {
    if (value == null || value.isEmpty || !value.contains(':')) return null;
    try {
      final parts = value.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return TimeOfDay(hour: h, minute: m);
    } catch (_) {
      return null;
    }
  }

  String? _timeOfDayToJson(TimeOfDay? time) {
    if (time == null) return null;
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
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

