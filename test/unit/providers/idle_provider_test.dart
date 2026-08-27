import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/platform/idle_detector_service.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/data/repositories/sqlite_category_repository.dart';
import 'package:workpulse/data/repositories/sqlite_idle_period_repository.dart';
import 'package:workpulse/data/repositories/sqlite_project_repository.dart';
import 'package:workpulse/data/repositories/sqlite_session_repository.dart';
import 'package:workpulse/data/repositories/sqlite_settings_repository.dart';
import 'package:workpulse/data/repositories/sqlite_work_item_repository.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/activity_heartbeat_service.dart';
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
    late SqliteSettingsRepository settingsRepo;
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
      settingsRepo = SqliteSettingsRepository(dbService);

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
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
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

  group('IdleNotifier unaccounted-gap recovery', () {
    late DatabaseService dbService;
    late SqliteSessionRepository sessionRepo;
    late SqliteIdlePeriodRepository idleRepo;
    late SqliteWorkItemRepository workItemRepo;
    late SqliteSettingsRepository settingsRepo;
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
      settingsRepo = SqliteSettingsRepository(dbService);

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

      final proj = await SqliteProjectRepository(dbService).create(
        Project(
            id: 'proj-1',
            workspaceId: wsId,
            name: 'Core',
            createdAt: now,
            updatedAt: now),
      );
      final cat = await SqliteCategoryRepository(dbService).create(
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
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          timerServiceProvider.overrideWithValue(timerService),
          idleServiceProvider.overrideWithValue(idleService),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    /// Reproduces the reported bug: a timer left running overnight while the
    /// laptop was switched off, so no live idle poll ever ran.
    Future<Session> leaveSessionRunningOvernight() async {
      final lastNight =
          DateTime.now().toUtc().subtract(const Duration(hours: 8));
      final session = await sessionRepo.create(Session(
        id: 'sess-overnight',
        workItemId: testTask.id,
        startTime: lastNight,
        createdAt: lastNight,
      ));
      await settingsRepo.setSetting(
        ActivityHeartbeatService.settingsKey,
        lastNight.add(const Duration(minutes: 2)).toIso8601String(),
      );
      return session;
    }

    test('prompts for the hours the app was not running', () async {
      final session = await leaveSessionRunningOvernight();

      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      await container
          .read(idleNotifierProvider.notifier)
          .checkForUnaccountedGap();

      final state = container.read(idleNotifierProvider);
      expect(state.isPromptVisible, isTrue);
      expect(state.currentEvent?.trigger, IdleTrigger.appNotRunning);
      expect(state.activeSession?.id, session.id);
      expect(state.activeWorkItem?.id, testTask.id);
      expect(
        state.currentEvent!.idleDuration,
        greaterThan(const Duration(hours: 7, minutes: 30)),
      );
    });

    test('discarding the gap ends the session at the last heartbeat', () async {
      await leaveSessionRunningOvernight();

      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final notifier = container.read(idleNotifierProvider.notifier);
      await notifier.checkForUnaccountedGap();
      final gapStart =
          container.read(idleNotifierProvider).currentEvent!.idleStartTime;

      await notifier.stopSession();

      expect(container.read(idleNotifierProvider).isPromptVisible, isFalse);
      expect(await sessionRepo.getActiveSession(), isNull);

      final stopped = await sessionRepo.getById('sess-overnight');
      expect(stopped!.endTime, gapStart);
      expect(stopped.duration, lessThan(const Duration(minutes: 3)));

      final periods = await idleRepo.getIdlePeriodsForSession('sess-overnight');
      expect(periods.single.resolution, IdleResolution.stopSession);
    });

    test('resolving re-baselines the heartbeat so the next launch is quiet',
        () async {
      await leaveSessionRunningOvernight();

      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final notifier = container.read(idleNotifierProvider.notifier);
      await notifier.checkForUnaccountedGap();
      await notifier.keepTracking();

      final heartbeat = container.read(activityHeartbeatServiceProvider);
      final recorded = await heartbeat.readLastHeartbeat();
      expect(recorded, isNotNull);
      expect(
        DateTime.now().toUtc().difference(recorded!),
        lessThan(const Duration(minutes: 1)),
      );

      // The next launch — a fresh container, same database — finds nothing
      // left to ask about.
      final nextLaunch = createContainer();
      await nextLaunch.read(currentWorkspaceProvider.future);
      await nextLaunch.read(timerProvider.future);
      await nextLaunch
          .read(idleNotifierProvider.notifier)
          .checkForUnaccountedGap();

      expect(nextLaunch.read(idleNotifierProvider).isPromptVisible, isFalse);
    });

    test('only checks once per launch, so a shell rebuild cannot re-prompt',
        () async {
      await leaveSessionRunningOvernight();

      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      final notifier = container.read(idleNotifierProvider.notifier);
      await notifier.checkForUnaccountedGap();
      notifier.dismiss();

      // Opening and closing Quick Capture remounts the shell, which calls
      // startup recovery again.
      await notifier.checkForUnaccountedGap();

      expect(container.read(idleNotifierProvider).isPromptVisible, isFalse);
    });

    test('stays quiet and records a heartbeat when nothing is being tracked',
        () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      await container
          .read(idleNotifierProvider.notifier)
          .checkForUnaccountedGap();

      expect(container.read(idleNotifierProvider).isPromptVisible, isFalse);
      expect(
        await container
            .read(activityHeartbeatServiceProvider)
            .readLastHeartbeat(),
        isNotNull,
      );
    });

    test('stays quiet for a session started moments ago', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);

      await container.read(timerProvider.notifier).startTimer(testTask);
      await container
          .read(idleNotifierProvider.notifier)
          .checkForUnaccountedGap();

      expect(container.read(idleNotifierProvider).isPromptVisible, isFalse);
    });
  });

  group('A stretch of inactivity that keeps being re-reported', () {
    late DatabaseService dbService;
    late _FakeIdleDetector detector;
    late SqliteSessionRepository sessionRepo;
    late SqliteWorkItemRepository workItemRepo;
    late TimerService timerService;
    late WorkItem testTask;

    const wsId = MigrationV1.defaultWorkspaceId;
    final stretchStart = DateTime.utc(2026, 8, 27, 12, 27);

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      sessionRepo = SqliteSessionRepository(dbService);
      workItemRepo = SqliteWorkItemRepository(dbService);
      timerService = TimerService(
        sessionRepository: sessionRepo,
        workItemRepository: workItemRepo,
      );
      detector = _FakeIdleDetector();

      final now = DateTime.now().toUtc();
      final proj = await SqliteProjectRepository(dbService).create(
        Project(
            id: 'proj-1',
            workspaceId: wsId,
            name: 'Core',
            createdAt: now,
            updatedAt: now),
      );
      final cat = await SqliteCategoryRepository(dbService).create(
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
          name: 'Task 1',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(() async {
      detector.dispose();
      await dbService.close();
    });

    Future<ProviderContainer> startedContainer() async {
      final container = ProviderContainer(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(sessionRepo),
          idlePeriodRepositoryProvider
              .overrideWithValue(SqliteIdlePeriodRepository(dbService)),
          workItemRepositoryProvider.overrideWithValue(workItemRepo),
          timerServiceProvider.overrideWithValue(timerService),
          settingsRepositoryProvider
              .overrideWithValue(SqliteSettingsRepository(dbService)),
          idleDetectorServiceProvider.overrideWithValue(detector),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentWorkspaceProvider.future);
      await container.read(timerProvider.future);
      await container.read(timerProvider.notifier).startTimer(testTask);
      // Reading the notifier is what subscribes it to the detector.
      container.read(idleNotifierProvider.notifier);
      return container;
    }

    Future<void> report(Duration span) async {
      detector.emit(
        IdleDetectionEvent(
          idleDuration: span,
          idleStartTime: stretchStart,
          idleEndTime: stretchStart.add(span),
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }

    test('grows the figure on screen instead of freezing at the threshold',
        () async {
      final container = await startedContainer();

      await report(const Duration(minutes: 3));
      expect(
        container.read(idleNotifierProvider).currentEvent?.idleDuration,
        const Duration(minutes: 3),
      );

      await report(const Duration(minutes: 30));
      final state = container.read(idleNotifierProvider);
      expect(state.isPromptVisible, isTrue);
      expect(state.currentEvent?.idleDuration, const Duration(minutes: 30));
    });

    test('does not reopen itself after the user dismisses it', () async {
      final container = await startedContainer();
      await report(const Duration(minutes: 3));

      container.read(idleNotifierProvider.notifier).dismiss();
      expect(container.read(idleNotifierProvider).isPromptVisible, isFalse);

      // The user walked off again without touching anything, so the detector
      // keeps re-reporting the very same stretch.
      await report(const Duration(minutes: 12));
      expect(container.read(idleNotifierProvider).isPromptVisible, isFalse);
    });

    test('still raises a genuinely new stretch after one was dismissed',
        () async {
      final container = await startedContainer();
      await report(const Duration(minutes: 3));
      container.read(idleNotifierProvider.notifier).dismiss();

      detector.emit(
        IdleDetectionEvent(
          idleDuration: const Duration(minutes: 4),
          idleStartTime: stretchStart.add(const Duration(hours: 1)),
          idleEndTime: stretchStart.add(const Duration(hours: 1, minutes: 4)),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(idleNotifierProvider).isPromptVisible, isTrue);
    });
  });
}

/// A detector whose events the test writes by hand.
class _FakeIdleDetector implements IdleDetectorService {
  final _controller = StreamController<IdleDetectionEvent>.broadcast();
  Duration _threshold = const Duration(minutes: 3);

  void emit(IdleDetectionEvent event) => _controller.add(event);

  @override
  Duration get idleThreshold => _threshold;

  @override
  void setIdleThreshold(Duration duration) => _threshold = duration;

  @override
  Stream<IdleDetectionEvent> get onIdleDetected => _controller.stream;

  @override
  bool get isSupported => true;

  @override
  void startMonitoring({required bool isTracking}) {}

  @override
  void stopMonitoring() {}

  @override
  void dispose() => _controller.close();
}
