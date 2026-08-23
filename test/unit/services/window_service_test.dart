import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/platform/window_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WindowService & NoOpWindowService Unit Tests', () {
    late NoOpWindowService windowService;

    setUp(() {
      windowService = NoOpWindowService();
    });

    test('initial mode is dashboard', () {
      expect(windowService.currentMode, WindowMode.dashboard);
      expect(windowService.windowModeNotifier.value, WindowMode.dashboard);
      expect(windowService.visible, isTrue);
    });

    test('openQuickCapture sets mode to quickCapture and makes visible', () async {
      await windowService.openQuickCapture();

      expect(windowService.currentMode, WindowMode.quickCapture);
      expect(windowService.windowModeNotifier.value, WindowMode.quickCapture);
      expect(windowService.visible, isTrue);
      expect(windowService.focused, isTrue);
    });

    test('closeQuickCapture sets mode back to dashboard and hides window', () async {
      await windowService.openQuickCapture();
      expect(windowService.currentMode, WindowMode.quickCapture);

      await windowService.closeQuickCapture();
      expect(windowService.currentMode, WindowMode.dashboard);
      expect(windowService.windowModeNotifier.value, WindowMode.dashboard);
      expect(windowService.visible, isFalse);
    });

    test('openDashboard sets mode to dashboard and makes visible', () async {
      await windowService.closeQuickCapture();
      expect(windowService.visible, isFalse);

      await windowService.openDashboard();
      expect(windowService.currentMode, WindowMode.dashboard);
      expect(windowService.windowModeNotifier.value, WindowMode.dashboard);
      expect(windowService.visible, isTrue);
      expect(windowService.focused, isTrue);
    });

    test('DesktopWindowService singleton instance is consistent', () {
      final instance1 = DesktopWindowService.instance;
      final instance2 = DesktopWindowService();
      expect(identical(instance1, instance2), isTrue);
      expect(instance1.currentMode, WindowMode.dashboard);
    });
  });
}
