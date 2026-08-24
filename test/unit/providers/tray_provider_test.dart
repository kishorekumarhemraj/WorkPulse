import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/platform/tray_service.dart';
import 'package:workpulse/core/platform/window_service.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/data/repositories/sqlite_category_repository.dart';
import 'package:workpulse/data/repositories/sqlite_project_repository.dart';
import 'package:workpulse/data/repositories/sqlite_session_repository.dart';
import 'package:workpulse/data/repositories/sqlite_work_item_repository.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/data/repositories/sqlite_settings_repository.dart';
import 'package:workpulse/domain/repositories/settings_repository.dart';
import 'package:workpulse/domain/services/activity_heartbeat_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/timer/models/timer_state.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/tray/providers/tray_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('TrayCoordinator Unit Tests', () {
    late DatabaseService dbService;
    late SqliteSessionRepository sessionRepo;
    late SqliteWorkItemRepository workItemRepo;
    late SqliteProjectRepository projectRepo;
    late SqliteCategoryRepository categoryRepo;
    late TimerService timerService;
    late NoOpTrayService fakeTrayService;
    late NoOpWindowService fakeWindowService;

    const wsId = MigrationV1.defaultWorkspaceId;
    late WorkItem testTask;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      sessionRepo = SqliteSessionRepository(dbService);
      workItemRepo = SqliteWorkItemRepository(dbService);
      projectRepo = SqliteProjectRepository(dbService);
      categoryRepo = SqliteCategoryRepository(dbService);

      timerService = TimerService(
        sessionRepository: sessionRepo,
        workItemRepository: workItemRepo,
      );

      fakeTrayService = NoOpTrayService();
      fakeWindowService = NoOpWindowService();

      final now = DateTime.now().toUtc();

      final proj = await projectRepo.create(
        Project(
            id: 'proj-1',
            workspaceId: wsId,
            name: 'Core',
            createdAt: now,
            updatedAt: now),
      );

      final cat = await categoryRepo.create(
        Category(
            id: 'cat-1',
            workspaceId: wsId,
            name: 'Dev',
            createdAt: now,
            updatedAt: now),
      );

      testTask = await workItemRepo.create(
        WorkItem(
          id: 'task-1',
          workspaceId: wsId,
          projectId: proj.id,
          categoryId: cat.id,
          name: 'Menu Bar Integration',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(() async {
      await dbService.close();
    });

    ProviderContainer createContainer({
      Future<void> Function(int code)? exitProcess,
      SettingsRepository? settingsRepository,
    }) {
      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWithValue(dbService),
          if (settingsRepository != null)
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
          sessionRepositoryProvider.overrideWithValue(sessionRepo),
          workItemRepositoryProvider.overrideWithValue(workItemRepo),
          timerServiceProvider.overrideWithValue(timerService),
          trayServiceProvider.overrideWithValue(fakeTrayService),
          windowServiceProvider.overrideWithValue(fakeWindowService),
          if (exitProcess != null)
            processExitProvider.overrideWithValue(exitProcess),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('updateTrayState sets idle text and menu when timer is stopped',
        () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final coordinator = container.read(trayCoordinatorProvider);
      await coordinator
          .updateTrayState(const TimerState(status: TimerStatus.idle));

      expect(fakeTrayService.currentTitle, 'WorkPulse');
      expect(fakeTrayService.currentToolTip, contains('Ready'));
      expect(
          fakeTrayService.currentMenu
              .any((item) => item.label.contains('No Active Timer')),
          isTrue);
    });

    test(
        'updateTrayState sets active ticker and task menu when timer is running',
        () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final coordinator = container.read(trayCoordinatorProvider);
      await coordinator.initialize();

      final timerNotifier = container.read(timerProvider.notifier);
      await timerNotifier.startTimer(testTask);
      await Future<void>.delayed(Duration.zero);

      expect(fakeTrayService.currentTitle, contains('⏱'));
      expect(fakeTrayService.currentToolTip, 'Tracking: Menu Bar Integration');
      expect(
          fakeTrayService.currentMenu
              .any((item) => item.label == '● Menu Bar Integration'),
          isTrue);
      expect(
          fakeTrayService.currentMenu.any((item) => item.key == 'stop_timer'),
          isTrue);
    });

    test('tray menu actions show the window and open Quick Capture', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      container.read(trayCoordinatorProvider);

      fakeTrayService.menuItemClickListener?.call('show_window');
      expect(fakeWindowService.visible, isTrue);
      expect(fakeWindowService.currentMode, WindowMode.dashboard);

      fakeTrayService.menuItemClickListener?.call('quick_capture');
      expect(fakeWindowService.visible, isTrue);
      expect(fakeWindowService.currentMode, WindowMode.quickCapture);
    });

    // Regression: the menu handler invoked a shell-registered callback *and*
    // opened the window itself. The second open saw the mode already switched
    // and cleared the "restore the dashboard afterwards" flag, so dismissing
    // Quick Capture hid the app instead of returning to it.
    test('Quick Capture opens exactly once per tray click', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);
      container.read(trayCoordinatorProvider);

      fakeTrayService.menuItemClickListener?.call('quick_capture');

      expect(fakeWindowService.openQuickCaptureCount, 1);
    });

    // A bare exit(0) left the last heartbeat up to 30s stale, so the next
    // launch asked the user to account for time they had actually worked.
    test('quitting writes a final heartbeat, then closes down and exits',
        () async {
      final exitCodes = <int>[];
      final recorder = _RecordingSettingsRepository(
        SqliteSettingsRepository(dbService),
      );
      final container = createContainer(
        exitProcess: (code) async => exitCodes.add(code),
        settingsRepository: recorder,
      );
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      await container.read(trayCoordinatorProvider).quitApp();

      expect(
          recorder.writtenKeys, contains(ActivityHeartbeatService.settingsKey));
      expect(dbService.isInitialized, isFalse, reason: 'database was closed');
      expect(exitCodes, [0]);
    });
  });
}

/// Records which settings keys were written, so the graceful-quit path can be
/// asserted without keeping the database open to read them back.
class _RecordingSettingsRepository implements SettingsRepository {
  final SettingsRepository _inner;
  final writtenKeys = <String>[];

  _RecordingSettingsRepository(this._inner);

  @override
  Future<String?> getSetting(String key) => _inner.getSetting(key);

  @override
  Future<void> setSetting(String key, String value) {
    writtenKeys.add(key);
    return _inner.setSetting(key, value);
  }

  @override
  Future<void> removeSetting(String key) => _inner.removeSetting(key);

  @override
  Future<Map<String, String>> getAllSettings() => _inner.getAllSettings();
}
