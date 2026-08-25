import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('IdleService SQLite Unit Tests', () {
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
          name: 'Implement Idle System',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(() async {
      await dbService.close();
    });

    test(
        'resolveKeepTracking records idle period in SQLite and keeps session active',
        () async {
      final now = DateTime.now().toUtc();
      final startTime = now.subtract(const Duration(minutes: 30));
      final idleStart = now.subtract(const Duration(minutes: 10));
      final idleEnd = now;

      final session =
          await timerService.startSession(testTask.id, startTime: startTime);

      final result = await idleService.resolveKeepTracking(
        sessionId: session.id,
        idleStartTime: idleStart,
        idleEndTime: idleEnd,
      );

      expect(result.idlePeriod.resolution, IdleResolution.keepTracking);
      expect(result.idlePeriod.duration, const Duration(minutes: 10));

      // Verify in SQLite
      final idlePeriods = await idleRepo.getIdlePeriodsForSession(session.id);
      expect(idlePeriods.length, 1);
      expect(idlePeriods.first.resolution, IdleResolution.keepTracking);

      final active = await sessionRepo.getActiveSession();
      expect(active, isNotNull);
      expect(active!.id, session.id);
      expect(active.endTime, isNull);
    });

    test(
        'resolveMarkIdle stops session at idle start, records period, and starts new session',
        () async {
      final now = DateTime.now().toUtc();
      final startTime = now.subtract(const Duration(minutes: 45));
      final idleStart = now.subtract(const Duration(minutes: 20));
      final idleEnd = now;

      final sessionA =
          await timerService.startSession(testTask.id, startTime: startTime);

      final result = await idleService.resolveMarkIdle(
        sessionId: sessionA.id,
        workItemId: testTask.id,
        idleStartTime: idleStart,
        idleEndTime: idleEnd,
      );

      expect(result.idlePeriod.resolution, IdleResolution.markIdle);
      expect(result.stoppedSession, isNotNull);
      expect(result.stoppedSession!.endTime, idleStart);
      expect(result.newSession, isNotNull);
      expect(result.newSession!.startTime, idleEnd);
      expect(result.newSession!.isActive, isTrue);

      // Verify SQLite state
      final stoppedInDb = await sessionRepo.getById(sessionA.id);
      expect(stoppedInDb!.endTime, idleStart);

      final activeInDb = await sessionRepo.getActiveSession();
      expect(activeInDb, isNotNull);
      expect(activeInDb!.id, result.newSession!.id);
      expect(activeInDb.startTime, idleEnd);
      expect(activeInDb.endTime, isNull);

      final idlePeriods = await idleRepo.getIdlePeriodsForSession(sessionA.id);
      expect(idlePeriods.length, 1);
      expect(idlePeriods.first.resolution, IdleResolution.markIdle);
    });

    test('resolveMarkIdle carries the interrupted session\'s classification',
        () async {
      final now = DateTime.now().toUtc();
      final startTime = now.subtract(const Duration(minutes: 45));

      // The half before the break is classified — by seeding, or because the
      // user set it. The half after is a continuation of the same work, so it
      // must not come back unclassified just because a break happened.
      final sessionA = await timerService.startSession(
        testTask.id,
        startTime: startTime,
        categoryId: 'cat-1',
      );
      expect(sessionA.categoryId, 'cat-1');

      final result = await idleService.resolveMarkIdle(
        sessionId: sessionA.id,
        workItemId: testTask.id,
        idleStartTime: now.subtract(const Duration(minutes: 20)),
        idleEndTime: now,
      );

      expect(result.newSession!.categoryId, 'cat-1');
    });

    test(
        'resolveStopSession stops active session at idle start and records period',
        () async {
      final now = DateTime.now().toUtc();
      final startTime = now.subtract(const Duration(minutes: 50));
      final idleStart = now.subtract(const Duration(minutes: 25));
      final idleEnd = now;

      final session =
          await timerService.startSession(testTask.id, startTime: startTime);

      final result = await idleService.resolveStopSession(
        sessionId: session.id,
        idleStartTime: idleStart,
        idleEndTime: idleEnd,
      );

      expect(result.idlePeriod.resolution, IdleResolution.stopSession);
      expect(result.stoppedSession!.endTime, idleStart);
      expect(result.newSession, isNull);

      // Verify no active session remaining in SQLite
      final active = await sessionRepo.getActiveSession();
      expect(active, isNull);

      final stoppedInDb = await sessionRepo.getById(session.id);
      expect(stoppedInDb!.endTime, idleStart);

      final idlePeriods = await idleRepo.getIdlePeriodsForSession(session.id);
      expect(idlePeriods.length, 1);
      expect(idlePeriods.first.resolution, IdleResolution.stopSession);
    });
  });
}
