import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/data/repositories/sqlite_category_repository.dart';
import 'package:workpulse/data/repositories/sqlite_project_repository.dart';
import 'package:workpulse/data/repositories/sqlite_session_repository.dart';
import 'package:workpulse/data/repositories/sqlite_work_item_repository.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/timer/models/timer_state.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('TimerNotifier Unit Tests', () {
    late DatabaseService dbService;
    late SqliteProjectRepository projectRepo;
    late SqliteCategoryRepository categoryRepo;
    late SqliteWorkItemRepository workItemRepo;
    late SqliteSessionRepository sessionRepo;

    const wsId = MigrationV1.defaultWorkspaceId;
    late Project defaultProject;
    late Category defaultCategory;
    late WorkItem taskA;
    late WorkItem taskB;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      projectRepo = SqliteProjectRepository(dbService);
      categoryRepo = SqliteCategoryRepository(dbService);
      workItemRepo = SqliteWorkItemRepository(dbService);
      sessionRepo = SqliteSessionRepository(dbService);

      final now = DateTime.now().toUtc();

      defaultProject = await projectRepo.create(
        Project(
          id: 'proj-1',
          workspaceId: wsId,
          name: 'Core System',
          createdAt: now,
          updatedAt: now,
        ),
      );

      defaultCategory = await categoryRepo.create(
        Category(
          id: 'cat-1',
          workspaceId: wsId,
          name: 'Engineering',
          createdAt: now,
          updatedAt: now,
        ),
      );

      taskA = await workItemRepo.create(
        WorkItem(
          id: 'task-a',
          workspaceId: wsId,
          projectId: defaultProject.id,
          categoryId: defaultCategory.id,
          name: 'Task Alpha',
          createdAt: now,
          updatedAt: now,
        ),
      );

      taskB = await workItemRepo.create(
        WorkItem(
          id: 'task-b',
          workspaceId: wsId,
          projectId: defaultProject.id,
          categoryId: defaultCategory.id,
          name: 'Task Beta',
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
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('initializes to idle when no active session exists in SQLite', () async {
      final container = createContainer();
      final timerState = await container.read(timerProvider.future);

      expect(timerState.status, TimerStatus.idle);
      expect(timerState.isRunning, isFalse);
      expect(timerState.activeSession, isNull);
      expect(timerState.activeWorkItem, isNull);
    });

    test('startup recovery: restores running state if an active session exists in SQLite', () async {
      final startTime = DateTime.now().toUtc().subtract(const Duration(minutes: 10));
      await sessionRepo.create(
        Session(
          id: 'sess-active',
          workItemId: taskA.id,
          startTime: startTime,
          createdAt: startTime,
        ),
      );

      final container = createContainer();
      final timerState = await container.read(timerProvider.future);

      expect(timerState.status, TimerStatus.running);
      expect(timerState.isRunning, isTrue);
      expect(timerState.activeSession, isNotNull);
      expect(timerState.activeSession!.id, 'sess-active');
      expect(timerState.activeWorkItem!.id, taskA.id);
      expect(timerState.elapsed.inMinutes, greaterThanOrEqualTo(9));
    });

    test('startTimer and stopTimer lifecycle', () async {
      final container = createContainer();
      await container.read(timerProvider.future);

      final notifier = container.read(timerProvider.notifier);

      // Start timer
      await notifier.startTimer(taskA);
      var state = container.read(timerProvider).value!;
      expect(state.status, TimerStatus.running);
      expect(state.activeWorkItem!.id, taskA.id);
      expect(state.activeSession, isNotNull);

      // Stop timer
      final stopped = await notifier.stopTimer();
      expect(stopped, isNotNull);
      expect(stopped!.endTime, isNotNull);

      state = container.read(timerProvider).value!;
      expect(state.status, TimerStatus.idle);
      expect(state.isRunning, isFalse);
      expect(state.activeSession, isNull);
    });

    test('task switching: requestSwitch, confirmSwitch, and cancelSwitch flow', () async {
      final container = createContainer();
      await container.read(timerProvider.future);

      final notifier = container.read(timerProvider.notifier);

      // Start on Task A
      await notifier.startTimer(taskA);
      expect(container.read(timerProvider).value!.activeWorkItem!.id, taskA.id);

      // Calling startTimer on Task B while Task A is active triggers requestSwitch
      await notifier.startTimer(taskB);
      var state = container.read(timerProvider).value!;
      expect(state.status, TimerStatus.switching);
      expect(state.pendingSwitchWorkItem!.id, taskB.id);
      expect(state.activeWorkItem!.id, taskA.id);

      // Cancel switch
      notifier.cancelSwitch();
      state = container.read(timerProvider).value!;
      expect(state.status, TimerStatus.running);
      expect(state.pendingSwitchWorkItem, isNull);
      expect(state.activeWorkItem!.id, taskA.id);

      // Request switch again and confirm
      notifier.requestSwitch(taskB);
      await notifier.confirmSwitch();

      state = container.read(timerProvider).value!;
      expect(state.status, TimerStatus.running);
      expect(state.activeWorkItem!.id, taskB.id);
      expect(state.pendingSwitchWorkItem, isNull);

      // Verify in DB that old session for taskA is stopped and new session for taskB is active
      final active = await sessionRepo.getActiveSession();
      expect(active!.workItemId, taskB.id);
    });
  });
}
