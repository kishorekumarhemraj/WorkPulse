import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/platform/tray_service.dart';
import 'package:workpulse/core/platform/window_service.dart';
import 'package:workpulse/features/tray/providers/tray_provider.dart';

void main() {
  group('TrayService and WindowService Unit Tests', () {
    test('TrayCoordinator formatDuration properly formats HH:MM:SS and MM:SS', () {
      final container = ProviderContainer(
        overrides: [
          trayServiceProvider.overrideWithValue(NoOpTrayService()),
          windowServiceProvider.overrideWithValue(NoOpWindowService()),
        ],
      );
      addTearDown(container.dispose);

      final coordinator = container.read(trayCoordinatorProvider);

      expect(coordinator.formatDuration(const Duration(seconds: 45)), '00:00:45');
      expect(coordinator.formatDuration(const Duration(minutes: 5, seconds: 9)), '00:05:09');
      expect(coordinator.formatDuration(const Duration(hours: 1, minutes: 23, seconds: 45)), '01:23:45');
      expect(coordinator.formatDuration(const Duration(hours: 10, minutes: 0, seconds: 1)), '10:00:01');
    });

    test('NoOpTrayService stores title, tooltip, and menu items', () async {
      final trayService = NoOpTrayService();

      await trayService.setTitle('⏱ 01:00:00');
      expect(trayService.currentTitle, '⏱ 01:00:00');

      await trayService.setToolTip('Tracking: Core Architecture');
      expect(trayService.currentToolTip, 'Tracking: Core Architecture');

      const menu = [
        TrayMenuItem(label: '● Core Architecture', disabled: true),
        TrayMenuItem.separator(),
        TrayMenuItem(key: 'stop_timer', label: 'Stop Timer'),
      ];
      await trayService.setContextMenu(menu);
      expect(trayService.currentMenu.length, 3);
      expect(trayService.currentMenu[0].label, '● Core Architecture');
      expect(trayService.currentMenu[1].isSeparator, isTrue);
      expect(trayService.currentMenu[2].key, 'stop_timer');
    });

    test('NoOpWindowService tracks show, hide, and focus state', () async {
      final windowService = NoOpWindowService();

      await windowService.hide();
      expect(windowService.visible, isFalse);
      expect(await windowService.isVisible(), isFalse);

      await windowService.show();
      expect(windowService.visible, isTrue);
      expect(windowService.focused, isTrue);
      expect(await windowService.isVisible(), isTrue);
    });
  });
}
