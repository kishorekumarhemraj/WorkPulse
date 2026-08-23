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
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/task_switch_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/timer/models/timer_state.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Task Switching End-to-End Integration Tests', () {
    late DatabaseService dbService;
    late SqliteProjectRepository projectRepo;
    late SqliteCategoryRepository categoryRepo;
    late SqliteWorkItemRepository workItemRepo;
    late SqliteSessionRepository sessionRepo;
    late TimerService timerService;
    late TaskSwitchService switchService;

    const wsId = MigrationV1.defaultWorkspaceId;
    late Project defaultProject;
    late Category defaultCategory;
    late WorkItem taskA;
    late WorkItem taskB;
    late WorkItem taskC;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      projectRepo = SqliteProjectRepository(dbService);
      categoryRepo = SqliteCategoryRepository(dbService);
      workItemRepo = SqliteWorkItemRepository(dbService);
      sessionRepo = SqliteSessionRepository(dbService);

      timerService = TimerService(
        sessionRepository: sessionRepo,
        workItemRepository: workItemRepo,
      );

      switchService = TaskSwitchService(
        timerService: timerService,
        sessionRepository: sessionRepo,
        workItemRepository: workItemRepo,
      );

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

      taskC = await workItemRepo.create(
        WorkItem(
          id: 'task-c',
          workspaceId: wsId,
          projectId: defaultProject.id,
          categoryId: defaultCategory.id,
          name: 'Task Gamma',
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
          projectRepositoryProvider.overrideWithValue(projectRepo),
          categoryRepositoryProvider.overrideWithValue(categoryRepo),
          timerServiceProvider.overrideWithValue(timerService),
          taskSwitchServiceProvider.overrideWithValue(switchService),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('atomic task switch stops Session A with notes and starts Session B', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final notifier = container.read(timerProvider.notifier);

      // 1. Start tracking Task A
      await notifier.startTimer(taskA);

      // Verify Session A is active in SQLite
      final activeA = await sessionRepo.getActiveSession();
      expect(activeA, isNotNull);
      expect(activeA!.workItemId, taskA.id);
      expect(activeA.endTime, isNull);

      // 2. Request switch to Task B
      notifier.requestSwitch(taskB);
      expect(container.read(timerProvider).value!.status, TimerStatus.switching);
      expect(container.read(timerProvider).value!.pendingSwitchWorkItem!.id, taskB.id);

      // 3. Confirm switch with closing session note
      await notifier.confirmSwitch(notes: 'Completed initial architecture');

      // 4. Verify in SQLite
      final allSessions = await sessionRepo.getByWorkItemId(taskA.id);
      expect(allSessions.length, 1);
      expect(allSessions.first.endTime, isNotNull);

      final updatedTaskA = await workItemRepo.getById(taskA.id);
      expect(updatedTaskA!.notes, contains('Completed initial architecture'));

      final activeB = await sessionRepo.getActiveSession();
      expect(activeB, isNotNull);
      expect(activeB!.workItemId, taskB.id);
      expect(activeB.endTime, isNull);

      // Verify timer state
      final timerState = container.read(timerProvider).value!;
      expect(timerState.status, TimerStatus.running);
      expect(timerState.activeWorkItem!.id, taskB.id);
    });

    test('multiple sequential switches maintain single active session invariant', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final notifier = container.read(timerProvider.notifier);

      // Start Task A
      await notifier.startTimer(taskA);

      // Switch to Task B
      notifier.requestSwitch(taskB);
      await notifier.confirmSwitch(notes: 'Worked on Task A');

      // Switch to Task C
      notifier.requestSwitch(taskC);
      await notifier.confirmSwitch(notes: 'Worked on Task B');

      // Switch back to Task A (Resume)
      notifier.requestSwitch(taskA);
      await notifier.confirmSwitch(notes: 'Worked on Task C');

      // Check SQLite state
      final sessionsA = await sessionRepo.getByWorkItemId(taskA.id);
      final sessionsB = await sessionRepo.getByWorkItemId(taskB.id);
      final sessionsC = await sessionRepo.getByWorkItemId(taskC.id);

      expect(sessionsA.length, 2); // 1 closed + 1 active
      expect(sessionsB.length, 1); // 1 closed
      expect(sessionsC.length, 1); // 1 closed

      final active = await sessionRepo.getActiveSession();
      expect(active, isNotNull);
      expect(active!.workItemId, taskA.id);
      expect(active.endTime, isNull);
    });

    test('cancelling switch request preserves active session untouched', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final notifier = container.read(timerProvider.notifier);

      await notifier.startTimer(taskA);
      final sessionA = await sessionRepo.getActiveSession();

      // Request switch to Task B then cancel
      notifier.requestSwitch(taskB);
      notifier.cancelSwitch();

      final state = container.read(timerProvider).value!;
      expect(state.status, TimerStatus.running);
      expect(state.activeWorkItem!.id, taskA.id);
      expect(state.pendingSwitchWorkItem, isNull);

      final currentSession = await sessionRepo.getActiveSession();
      expect(currentSession!.id, sessionA!.id);
      expect(currentSession.endTime, isNull);
    });
  });
}
