import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';
import 'package:workpulse/data/repositories/sqlite_category_repository.dart';
import 'package:workpulse/data/repositories/sqlite_project_repository.dart';
import 'package:workpulse/data/repositories/sqlite_session_repository.dart';
import 'package:workpulse/data/repositories/sqlite_work_item_repository.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/timer_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('TimerService Domain Unit Tests', () {
    late DatabaseService dbService;
    late SqliteProjectRepository projectRepo;
    late SqliteCategoryRepository categoryRepo;
    late SqliteWorkItemRepository workItemRepo;
    late SqliteSessionRepository sessionRepo;
    late TimerService timerService;

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

      timerService = TimerService(
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
          name: 'Dev',
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

    test('startSession starts a new active session and updates lastWorkedAt on work item', () async {
      final startTime = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
      final session = await timerService.startSession(taskA.id, startTime: startTime);

      expect(session.workItemId, taskA.id);
      expect(session.endTime, isNull);
      expect(session.isActive, isTrue);

      final active = await timerService.getActiveSession();
      expect(active, isNotNull);
      expect(active!.id, session.id);

      final updatedTaskA = await workItemRepo.getById(taskA.id);
      expect(updatedTaskA!.lastWorkedAt, isNotNull);
    });

    test('Single-Active-Session Invariant: starting session on taskB automatically stops session on taskA', () async {
      final time1 = DateTime.now().toUtc().subtract(const Duration(minutes: 30));
      final time2 = DateTime.now().toUtc().subtract(const Duration(minutes: 10));

      final sessionA = await timerService.startSession(taskA.id, startTime: time1);
      expect(sessionA.isActive, isTrue);

      // Start session on Task B
      final sessionB = await timerService.startSession(taskB.id, startTime: time2);

      // Session A must now be stopped with endTime == time2
      final reloadedA = await sessionRepo.getById(sessionA.id);
      expect(reloadedA, isNotNull);
      expect(reloadedA!.endTime, equals(time2));
      expect(reloadedA.isActive, isFalse);

      // Session B must be active
      expect(sessionB.isActive, isTrue);
      final active = await timerService.getActiveSession();
      expect(active!.id, sessionB.id);
    });

    test('stopSession marks session as ended with timestamp', () async {
      final startTime = DateTime.now().toUtc().subtract(const Duration(minutes: 15));
      final endTime = DateTime.now().toUtc();

      final session = await timerService.startSession(taskA.id, startTime: startTime);
      final stopped = await timerService.stopSession(session.id, endTime: endTime);

      expect(stopped.endTime, equals(endTime));
      expect(stopped.isActive, isFalse);

      final active = await timerService.getActiveSession();
      expect(active, isNull);
    });

    test('getWorkItemTotalDuration aggregates multiple completed sessions plus active session', () async {
      final base = DateTime.now().toUtc().subtract(const Duration(hours: 3));

      // Session 1: 30 mins
      final s1 = await timerService.startSession(taskA.id, startTime: base);
      await timerService.stopSession(s1.id, endTime: base.add(const Duration(minutes: 30)));

      // Session 2: 45 mins
      final s2 = await timerService.startSession(taskA.id, startTime: base.add(const Duration(hours: 1)));
      await timerService.stopSession(s2.id, endTime: base.add(const Duration(hours: 1, minutes: 45)));

      // Duration so far: 30 + 45 = 75 minutes (1h 15m)
      final durationBeforeActive = await timerService.getWorkItemTotalDuration(taskA.id);
      expect(durationBeforeActive, const Duration(minutes: 75));

      // Active Session 3: started 15 mins ago
      final s3StartTime = DateTime.now().toUtc().subtract(const Duration(minutes: 15));
      final s3 = await timerService.startSession(taskA.id, startTime: s3StartTime);

      final totalDurationWithActive = await timerService.getWorkItemTotalDuration(taskA.id, activeSession: s3);
      expect(totalDurationWithActive.inMinutes, greaterThanOrEqualTo(90));
    });

    test('formatDuration formats correctly in standard and compact modes', () {
      expect(TimerService.formatDuration(const Duration(seconds: 45)), '00:45');
      expect(TimerService.formatDuration(const Duration(minutes: 5, seconds: 12)), '05:12');
      expect(TimerService.formatDuration(const Duration(hours: 1, minutes: 23, seconds: 45)), '01:23:45');

      expect(TimerService.formatDuration(const Duration(seconds: 45), compact: true), '45s');
      expect(TimerService.formatDuration(const Duration(minutes: 5, seconds: 12), compact: true), '5m 12s');
      expect(TimerService.formatDuration(const Duration(hours: 2, minutes: 30), compact: true), '2h 30m');
    });
  });
}
