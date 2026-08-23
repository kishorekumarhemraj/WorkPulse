import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/data/repositories/sqlite_category_repository.dart';
import 'package:workpulse/data/repositories/sqlite_idle_period_repository.dart';
import 'package:workpulse/data/repositories/sqlite_project_repository.dart';
import 'package:workpulse/data/repositories/sqlite_session_repository.dart';
import 'package:workpulse/data/repositories/sqlite_work_item_repository.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/idle_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/idle/providers/idle_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('IdleNotifier Unit Tests', () {
    late DatabaseService dbService;
    late SqliteSessionRepository sessionRepo;
    late SqliteIdlePeriodRepository idleRepo;
    late SqliteWorkItemRepository workItemRepo;
    late SqliteProjectRepository projectRepo;
    late SqliteCategoryRepository categoryRepo;
    late TimerService timerService;
    late IdleService idleService;

    const wsId = MigrationV1.defaultWorkspaceId;
    late WorkItem testTask;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      sessionRepo = SqliteSessionRepository(dbService);
      idleRepo = SqliteIdlePeriodRepository(dbService);
      workItemRepo = SqliteWorkItemRepository(dbService);
      projectRepo = SqliteProjectRepository(dbService);
      categoryRepo = SqliteCategoryRepository(dbService);

      timerService = TimerService(
        sessionRepository: sessionRepo,
        workItemRepository: workItemRepo,
      );

      idleService = IdleService(
        sessionRepository: sessionRepo,
        idlePeriodRepository: idleRepo,
        timerService: timerService,
      );

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
          name: 'Task 1',
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
          idlePeriodRepositoryProvider.overrideWithValue(idleRepo),
          workItemRepositoryProvider.overrideWithValue(workItemRepo),
          timerServiceProvider.overrideWithValue(timerService),
          idleServiceProvider.overrideWithValue(idleService),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('triggerPrompt sets prompt visible when timer is running', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final timerNotifier = container.read(timerProvider.notifier);
      await timerNotifier.startTimer(testTask);

      final idleNotifier = container.read(idleNotifierProvider.notifier);
      idleNotifier.triggerPrompt(idleDuration: const Duration(minutes: 10));

      final state = container.read(idleNotifierProvider);
      expect(state.isPromptVisible, isTrue);
      expect(state.activeWorkItem?.id, testTask.id);
      expect(state.currentEvent?.idleDuration, const Duration(minutes: 10));
    });

    test('keepTracking records in SQLite and dismisses prompt', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final timerNotifier = container.read(timerProvider.notifier);
      await timerNotifier.startTimer(testTask);

      final idleNotifier = container.read(idleNotifierProvider.notifier);
      idleNotifier.triggerPrompt(idleDuration: const Duration(minutes: 10));

      await idleNotifier.keepTracking();

      final state = container.read(idleNotifierProvider);
      expect(state.isPromptVisible, isFalse);

      final active = await sessionRepo.getActiveSession();
      expect(active, isNotNull);

      final periods = await idleRepo.getIdlePeriodsForSession(active!.id);
      expect(periods.length, 1);
      expect(periods.first.resolution, IdleResolution.keepTracking);
    });

    test('markIdle splits session and updates active timer', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final timerNotifier = container.read(timerProvider.notifier);
      await timerNotifier.startTimer(testTask);

      final initialActive = await sessionRepo.getActiveSession();
      expect(initialActive, isNotNull);

      final idleNotifier = container.read(idleNotifierProvider.notifier);
      idleNotifier.triggerPrompt(idleDuration: const Duration(minutes: 15));

      await idleNotifier.markIdle();

      final state = container.read(idleNotifierProvider);
      expect(state.isPromptVisible, isFalse);

      final newActive = await sessionRepo.getActiveSession();
      expect(newActive, isNotNull);
      expect(newActive!.id, isNot(initialActive!.id));
    });

    test('stopSession stops timer and dismisses prompt', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final timerNotifier = container.read(timerProvider.notifier);
      await timerNotifier.startTimer(testTask);

      final idleNotifier = container.read(idleNotifierProvider.notifier);
      idleNotifier.triggerPrompt(idleDuration: const Duration(minutes: 15));

      await idleNotifier.stopSession();

      final state = container.read(idleNotifierProvider);
      expect(state.isPromptVisible, isFalse);

      final active = await sessionRepo.getActiveSession();
      expect(active, isNull);
    });
  });
}
