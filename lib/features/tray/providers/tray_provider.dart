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
  return DesktopWindowService();
});

final trayCoordinatorProvider = Provider<TrayCoordinator>((ref) {
  final coordinator = TrayCoordinator(ref);
  coordinator.initialize();
  return coordinator;
});

class TrayCoordinator {
  final Ref _ref;
  void Function()? onQuickCaptureRequested;

  TrayCoordinator(this._ref);

  TrayService get _trayService => _ref.read(trayServiceProvider);
  WindowService get _windowService => _ref.read(windowServiceProvider);

  Future<void> initialize() async {
    await _trayService.initialize();
    await _windowService.initialize();

    _trayService.setTrayClickListener(() {
      _windowService.show();
    });

    _trayService.setMenuItemClickListener(_handleMenuItemClick);

    // React to timer state changes
    _ref.listen<AsyncValue<TimerState>>(timerProvider, (_, next) {
      final state = next.value;
      if (state != null) {
        updateTrayState(state);
      }
    });

    // Initial tray sync
    final currentTimer = _ref.read(timerProvider).value;
    if (currentTimer != null) {
      await updateTrayState(currentTimer);
    } else {
      await _setIdleTrayState();
    }
  }

  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  Future<void> updateTrayState(TimerState state) async {
    if (state.isRunning && state.activeWorkItem != null) {
      final formattedTime = formatDuration(state.elapsed);
      final title = '⏱ $formattedTime';
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
    switch (key) {
      case 'show_window':
        _windowService.show();
        break;
      case 'quick_capture':
        onQuickCaptureRequested?.call();
        _windowService.show();
        break;
      case 'stop_timer':
        _ref.read(timerProvider.notifier).stopTimer();
        break;
      case 'quit_app':
        exit(0);
    }
  }
}
