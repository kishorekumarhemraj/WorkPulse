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
        Project(id: 'proj-1', workspaceId: wsId, name: 'Core', createdAt: now, updatedAt: now),
      );

      final cat = await categoryRepo.create(
        Category(id: 'cat-1', workspaceId: wsId, name: 'Dev', createdAt: now, updatedAt: now),
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

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(sessionRepo),
          workItemRepositoryProvider.overrideWithValue(workItemRepo),
          timerServiceProvider.overrideWithValue(timerService),
          trayServiceProvider.overrideWithValue(fakeTrayService),
          windowServiceProvider.overrideWithValue(fakeWindowService),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('updateTrayState sets idle text and menu when timer is stopped', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final coordinator = container.read(trayCoordinatorProvider);
      await coordinator.updateTrayState(const TimerState(status: TimerStatus.idle));

      expect(fakeTrayService.currentTitle, 'WorkPulse');
      expect(fakeTrayService.currentToolTip, contains('Ready'));
      expect(fakeTrayService.currentMenu.any((item) => item.label.contains('No Active Timer')), isTrue);
    });

    test('updateTrayState sets active ticker and task menu when timer is running', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final coordinator = container.read(trayCoordinatorProvider);

      final timerState = TimerState(
        status: TimerStatus.running,
        activeWorkItem: testTask,
        elapsed: const Duration(minutes: 12, seconds: 34),
      );

      await coordinator.updateTrayState(timerState);

      expect(fakeTrayService.currentTitle, '⏱ 00:12:34');
      expect(fakeTrayService.currentToolTip, 'Tracking: Menu Bar Integration');
      expect(fakeTrayService.currentMenu.any((item) => item.label == '● Menu Bar Integration'), isTrue);
      expect(fakeTrayService.currentMenu.any((item) => item.key == 'stop_timer'), isTrue);
    });

    test('tray menu actions show window and trigger quick capture callback', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final coordinator = container.read(trayCoordinatorProvider);

      bool quickCaptureInvoked = false;
      coordinator.onQuickCaptureRequested = () {
        quickCaptureInvoked = true;
      };

      // Test show window
      fakeTrayService.menuItemClickListener?.call('show_window');
      expect(fakeWindowService.visible, isTrue);

      // Test quick capture
      fakeTrayService.menuItemClickListener?.call('quick_capture');
      expect(quickCaptureInvoked, isTrue);
      expect(fakeWindowService.visible, isTrue);
    });
  });
}
