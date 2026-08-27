import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/constants/app_constants.dart';
import 'package:workpulse/core/platform/hotkey_service.dart';
import 'package:workpulse/core/platform/tray_service.dart';
import 'package:workpulse/core/platform/window_service.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/services/activity_heartbeat_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/idle/providers/idle_provider.dart';
import 'package:workpulse/features/quick_capture/views/quick_capture_body.dart';
import 'package:workpulse/features/settings/providers/app_settings_provider.dart';
import 'package:workpulse/features/timer/models/timer_state.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';

final trayServiceProvider = Provider<TrayService>((ref) {
  final service = DesktopTrayService();
  ref.onDispose(service.destroy);
  return service;
});

final windowServiceProvider = Provider<WindowService>((ref) {
  return DesktopWindowService.instance;
});

/// The global-shortcut bridge.
///
/// Platform-bridges rule 1 requires widgets to reach native services through a
/// provider rather than constructing them; the shell was building its own
/// `DesktopHotKeyService` directly, which also made it impossible to assert
/// hotkey registration in a widget test.
final hotKeyServiceProvider = Provider<HotKeyService>((ref) {
  final service = DesktopHotKeyService();
  ref.onDispose(service.unregisterAll);
  return service;
});

/// How the app terminates. Overridden in tests so quitting can be asserted
/// without taking the test runner down with it.
final processExitProvider = Provider<Future<void> Function(int code)>(
  (ref) => (code) async => exit(code),
);

final trayCoordinatorProvider = Provider<TrayCoordinator>((ref) {
  final trayService = ref.watch(trayServiceProvider);
  final windowService = ref.watch(windowServiceProvider);

  final coordinator = TrayCoordinator(
    ref: ref,
    trayService: trayService,
    windowService: windowService,
    exitProcess: ref.watch(processExitProvider),
  );

  ref.onDispose(coordinator.dispose);
  return coordinator;
});

class TrayCoordinator {
  final Ref _ref;
  final TrayService _trayService;
  final WindowService _windowService;
  final Future<void> Function(int code) _exit;
  bool _isDisposed = false;
  bool _isInitializing = false;

  TrayCoordinator({
    required Ref ref,
    required TrayService trayService,
    required WindowService windowService,
    Future<void> Function(int code)? exitProcess,
  })  : _ref = ref,
        _trayService = trayService,
        _windowService = windowService,
        _exit = exitProcess ?? _defaultExit {
    _trayService.setTrayClickListener(() {
      _windowService.openDashboard();
    });

    _trayService.setMenuItemClickListener(_handleMenuItemClick);

    // Synchronously listen to timer state
    _ref.listen<AsyncValue<TimerState>>(timerProvider, (_, next) {
      if (_isDisposed) return;
      final state = next.value;
      if (state != null) {
        updateTrayState(state);
      }
    });
  }

  static Future<void> _defaultExit(int code) async => exit(code);

  /// The menu entry for Quick Capture, labelled with the shortcut that is
  /// actually registered. It used to hardcode "⌥ + Space", which was wrong
  /// both on Windows and after the user changed the shortcut.
  TrayMenuItem get _quickCaptureItem {
    final hotKey = _ref.read(appSettingsProvider).value?.quickCaptureHotKey;
    final label = hotKey == null ? null : hotKeyLabel(hotKey);
    return TrayMenuItem(
      key: 'quick_capture',
      label: label == null ? 'Quick Capture' : 'Quick Capture ($label)',
    );
  }

  Future<void> initialize() async {
    if (_isInitializing || _isDisposed) return;
    _isInitializing = true;

    await _trayService.initialize();
    await _windowService.initialize();

    if (_isDisposed) return;
    final currentTimer = _ref.read(timerProvider).value;
    if (currentTimer != null && currentTimer.isRunning) {
      await updateTrayState(currentTimer);
    } else {
      await _setIdleTrayState();
    }
  }

  /// Delegates to the app's single duration formatter so the menu bar clock
  /// and the in-app timer can never drift apart.
  String formatDuration(Duration duration) =>
      TimerService.formatDuration(duration);

  Future<void> updateTrayState(TimerState state) async {
    if (_isDisposed) return;

    if (state.isRunning && state.activeWorkItem != null) {
      final formattedTime = formatDuration(state.elapsed);
      final taskName = state.activeWorkItem!.name;
      final displayTaskName =
          taskName.length > 25 ? '${taskName.substring(0, 25)}…' : taskName;
      final title = '⏱ $formattedTime  $displayTaskName';
      final tooltip = 'Tracking: ${state.activeWorkItem!.name}';

      await _trayService.setTitle(title);
      await _trayService.setToolTip(tooltip);

      await _trayService.setContextMenu([
        TrayMenuItem(label: '● ${state.activeWorkItem!.name}', disabled: true),
        TrayMenuItem(label: '⏱ $formattedTime', disabled: true),
        const TrayMenuItem.separator(),
        const TrayMenuItem(key: 'stop_timer', label: 'Stop Timer'),
        _quickCaptureItem,
        const TrayMenuItem.separator(),
        const TrayMenuItem(key: 'show_window', label: 'Open WorkPulse'),
        const TrayMenuItem.separator(),
        const TrayMenuItem(key: 'quit_app', label: 'Quit WorkPulse'),
      ]);
    } else {
      await _setIdleTrayState();
    }
  }

  Future<void> _setIdleTrayState() async {
    if (_isDisposed) return;

    await _trayService.setTitle('WorkPulse');
    await _trayService.setToolTip('${AppConstants.appName} - Ready');

    await _trayService.setContextMenu([
      const TrayMenuItem(label: '● No Active Timer', disabled: true),
      const TrayMenuItem.separator(),
      _quickCaptureItem,
      const TrayMenuItem.separator(),
      const TrayMenuItem(key: 'show_window', label: 'Open WorkPulse'),
      const TrayMenuItem.separator(),
      const TrayMenuItem(key: 'quit_app', label: 'Quit WorkPulse'),
    ]);
  }

  void _handleMenuItemClick(String key) {
    if (_isDisposed) return;

    switch (key) {
      case 'show_window':
        _windowService.openDashboard();
        break;
      case 'quick_capture':
        // Exactly one call. This used to also invoke a shell-supplied
        // callback that opened the window a second time; the second open
        // saw the mode already switched and so recorded "the dashboard was
        // not visible", which meant closing Quick Capture hid the app
        // instead of returning to the dashboard.
        _windowService.openQuickCapture(
          height: QuickCaptureBody.hudHeightFrom(
            _ref.read(attributeDefinitionsProvider).value ??
                const <AttributeDefinition>[],
          ),
        );
        break;
      case 'stop_timer':
        _ref.read(timerProvider.notifier).stopTimer();
        break;
      case 'quit_app':
        unawaited(quitApp());
    }
  }

  /// Quit, but leave the on-disk state consistent first.
  ///
  /// A bare `exit(0)` skips the app lifecycle callbacks, so the last
  /// heartbeat could be up to [ActivityHeartbeatService.defaultInterval] old
  /// and the next launch would ask the user to account for time they were
  /// actually working. Writing one final heartbeat and closing the database
  /// makes the recovered gap start at the moment of quit.
  @visibleForTesting
  Future<void> quitApp() async {
    try {
      await _ref.read(activityHeartbeatServiceProvider).beat();
    } catch (error) {
      debugPrint('[WorkPulse] Final heartbeat failed on quit: $error');
    }

    try {
      await _trayService.destroy();
    } catch (error) {
      debugPrint('[WorkPulse] Tray teardown failed on quit: $error');
    }

    try {
      await _ref.read(databaseServiceProvider).close();
    } catch (error) {
      debugPrint('[WorkPulse] Database close failed on quit: $error');
    }

    await _exit(0);
  }

  void dispose() {
    _isDisposed = true;
  }
}
