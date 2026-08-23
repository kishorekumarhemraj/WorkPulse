import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/constants/app_constants.dart';
import 'package:workpulse/core/platform/tray_service.dart';
import 'package:workpulse/core/platform/window_service.dart';
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

final trayCoordinatorProvider = Provider<TrayCoordinator>((ref) {
  final trayService = ref.watch(trayServiceProvider);
  final windowService = ref.watch(windowServiceProvider);

  final coordinator = TrayCoordinator(
    ref: ref,
    trayService: trayService,
    windowService: windowService,
  );

  ref.onDispose(coordinator.dispose);
  return coordinator;
});

class TrayCoordinator {
  final Ref _ref;
  final TrayService _trayService;
  final WindowService _windowService;
  bool _isDisposed = false;
  bool _isInitializing = false;
  void Function()? onQuickCaptureRequested;

  TrayCoordinator({
    required Ref ref,
    required TrayService trayService,
    required WindowService windowService,
  })  : _ref = ref,
        _trayService = trayService,
        _windowService = windowService {
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

  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

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
        const TrayMenuItem(key: 'quick_capture', label: 'Quick Capture (⌥ + Space)'),
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
      const TrayMenuItem(key: 'quick_capture', label: 'Quick Capture (⌥ + Space)'),
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
        onQuickCaptureRequested?.call();
        _windowService.openQuickCapture();
        break;
      case 'stop_timer':
        _ref.read(timerProvider.notifier).stopTimer();
        break;
      case 'quit_app':
        exit(0);
    }
  }

  void dispose() {
    _isDisposed = true;
  }
}
