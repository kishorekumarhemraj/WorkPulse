import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';
import 'package:workpulse/data/repositories/sqlite_category_repository.dart';
import 'package:workpulse/data/repositories/sqlite_project_repository.dart';
import 'package:workpulse/data/repositories/sqlite_session_repository.dart';
import 'package:workpulse/data/repositories/sqlite_settings_repository.dart';
import 'package:workpulse/data/repositories/sqlite_work_item_repository.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/activity_heartbeat_service.dart';
import 'package:workpulse/domain/services/idle_gap_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ActivityHeartbeatService', () {
    late DatabaseService dbService;
    late SqliteSettingsRepository settingsRepo;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);
      settingsRepo = SqliteSettingsRepository(dbService);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('reads back nothing before the first beat', () async {
      final service =
          ActivityHeartbeatService(settingsRepository: settingsRepo);

      expect(await service.readLastHeartbeat(), isNull);
    });

    test('beat persists the current instant as UTC', () async {
      final fixed = DateTime.utc(2026, 8, 23, 22, 15);
      final service = ActivityHeartbeatService(
        settingsRepository: settingsRepo,
        clock: () => fixed,
      );

      await service.beat();

      final read = await service.readLastHeartbeat();
      expect(read, fixed);
      expect(read!.isUtc, isTrue);
    });

    test('survives a rebuild of the service — the value lives in SQLite',
        () async {
      final fixed = DateTime.utc(2026, 8, 23, 22, 15);
      await ActivityHeartbeatService(
        settingsRepository: settingsRepo,
        clock: () => fixed,
      ).beat();

      // A brand-new instance stands in for the next launch of the app.
      final afterRestart =
          ActivityHeartbeatService(settingsRepository: settingsRepo);

      expect(await afterRestart.readLastHeartbeat(), fixed);
    });

    test('clear removes the stored heartbeat', () async {
      final service =
          ActivityHeartbeatService(settingsRepository: settingsRepo);
      await service.beat();
      await service.clear();

      expect(await service.readLastHeartbeat(), isNull);
    });

    test('a corrupt stored value reads as no heartbeat', () async {
      await settingsRepo.setSetting(
        ActivityHeartbeatService.settingsKey,
        'not-a-timestamp',
      );

      final service =
          ActivityHeartbeatService(settingsRepository: settingsRepo);

      expect(await service.readLastHeartbeat(), isNull);
    });
  });

  group('IdleGapService', () {
    const threshold = Duration(minutes: 5);
    const wsId = MigrationV1.defaultWorkspaceId;

    late DatabaseService dbService;
    late SqliteSessionRepository sessionRepo;
    late SqliteSettingsRepository settingsRepo;
    late ActivityHeartbeatService heartbeat;
    late IdleGapService gapService;
    late WorkItem testTask;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      sessionRepo = SqliteSessionRepository(dbService);
      settingsRepo = SqliteSettingsRepository(dbService);
      heartbeat = ActivityHeartbeatService(settingsRepository: settingsRepo);
      gapService = IdleGapService(
        sessionRepository: sessionRepo,
        heartbeatService: heartbeat,
      );

      final now = DateTime.now().toUtc();
      final projectRepo = SqliteProjectRepository(dbService);
      final categoryRepo = SqliteCategoryRepository(dbService);
      final workItemRepo = SqliteWorkItemRepository(dbService);

      final project = await projectRepo.create(Project(
        id: 'proj-1',
        workspaceId: wsId,
        name: 'Core',
        createdAt: now,
        updatedAt: now,
      ));
      final category = await categoryRepo.create(Category(
        id: 'cat-1',
        workspaceId: wsId,
        name: 'Dev',
        createdAt: now,
        updatedAt: now,
      ));
      testTask = await workItemRepo.create(WorkItem(
        id: 'task-1',
        workspaceId: wsId,
        projectId: project.id,
        categoryId: category.id,
        name: 'Task 1',
        createdAt: now,
        updatedAt: now,
      ));
    });

    tearDown(() async {
      await dbService.close();
    });

    Future<Session> startSessionAt(DateTime startTime) {
      return sessionRepo.create(Session(
        id: 'sess-1',
        workItemId: testTask.id,
        startTime: startTime,
        createdAt: startTime,
      ));
    }

    Future<void> writeHeartbeatAt(DateTime at) {
      return settingsRepo.setSetting(
        ActivityHeartbeatService.settingsKey,
        at.toIso8601String(),
      );
    }

    test('reports nothing when no session is open', () async {
      final now = DateTime.utc(2026, 8, 24, 9);
      await writeHeartbeatAt(now.subtract(const Duration(hours: 8)));

      expect(
        await gapService.detectUnaccountedGap(threshold: threshold, now: now),
        isNull,
      );
    });

    test('reports the overnight gap left by a laptop that was switched off',
        () async {
      // The reported bug: timer started at 23:00, machine off, app reopened at
      // 09:00. The heartbeat stops the moment the process dies.
      final now = DateTime.utc(2026, 8, 24, 9);
      await startSessionAt(DateTime.utc(2026, 8, 23, 23));
      await writeHeartbeatAt(DateTime.utc(2026, 8, 23, 23, 5));

      final gap =
          await gapService.detectUnaccountedGap(threshold: threshold, now: now);

      expect(gap, isNotNull);
      expect(gap!.startTime, DateTime.utc(2026, 8, 23, 23, 5));
      expect(gap.endTime, now);
      expect(gap.duration, const Duration(hours: 9, minutes: 55));
      expect(gap.session.id, 'sess-1');
    });

    test('reports nothing when the heartbeat is younger than the threshold',
        () async {
      final now = DateTime.utc(2026, 8, 24, 9);
      await startSessionAt(now.subtract(const Duration(hours: 2)));
      await writeHeartbeatAt(now.subtract(const Duration(seconds: 30)));

      expect(
        await gapService.detectUnaccountedGap(threshold: threshold, now: now),
        isNull,
      );
    });

    test('measures from the session start when no heartbeat was ever written',
        () async {
      final now = DateTime.utc(2026, 8, 24, 9);
      await startSessionAt(DateTime.utc(2026, 8, 24, 7));

      final gap =
          await gapService.detectUnaccountedGap(threshold: threshold, now: now);

      expect(gap, isNotNull);
      expect(gap!.startTime, DateTime.utc(2026, 8, 24, 7));
      expect(gap.duration, const Duration(hours: 2));
    });

    test('ignores a heartbeat that predates the session start', () async {
      // The heartbeat belongs to an earlier run and says nothing about this
      // session, so the session start is the honest lower bound.
      final now = DateTime.utc(2026, 8, 24, 9);
      await startSessionAt(DateTime.utc(2026, 8, 24, 7));
      await writeHeartbeatAt(DateTime.utc(2026, 8, 23, 18));

      final gap =
          await gapService.detectUnaccountedGap(threshold: threshold, now: now);

      expect(gap, isNotNull);
      expect(gap!.startTime, DateTime.utc(2026, 8, 24, 7));
      expect(gap.duration, const Duration(hours: 2));
    });

    test('reports nothing for a heartbeat in the future (clock moved back)',
        () async {
      final now = DateTime.utc(2026, 8, 24, 9);
      await startSessionAt(DateTime.utc(2026, 8, 24, 7));
      await writeHeartbeatAt(now.add(const Duration(hours: 1)));

      expect(
        await gapService.detectUnaccountedGap(threshold: threshold, now: now),
        isNull,
      );
    });

    test('reports nothing for a fresh session shorter than the threshold',
        () async {
      final now = DateTime.utc(2026, 8, 24, 9);
      await startSessionAt(now.subtract(const Duration(minutes: 1)));

      expect(
        await gapService.detectUnaccountedGap(threshold: threshold, now: now),
        isNull,
      );
    });

    test('a local-time now is compared in UTC', () async {
      final nowUtc = DateTime.utc(2026, 8, 24, 9);
      await startSessionAt(DateTime.utc(2026, 8, 23, 23));
      await writeHeartbeatAt(DateTime.utc(2026, 8, 23, 23, 5));

      final gap = await gapService.detectUnaccountedGap(
        threshold: threshold,
        now: nowUtc.toLocal(),
      );

      expect(gap, isNotNull);
      expect(gap!.duration, const Duration(hours: 9, minutes: 55));
    });
  });
}
