import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';
import 'package:workpulse/data/repositories/sqlite_attribute_repository.dart';
import 'package:workpulse/data/repositories/sqlite_category_repository.dart';
import 'package:workpulse/data/repositories/sqlite_idle_period_repository.dart';
import 'package:workpulse/data/repositories/sqlite_person_repository.dart';
import 'package:workpulse/data/repositories/sqlite_project_repository.dart';
import 'package:workpulse/data/repositories/sqlite_session_repository.dart';
import 'package:workpulse/data/repositories/sqlite_tag_repository.dart';
import 'package:workpulse/data/repositories/sqlite_work_item_repository.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/work_pattern_model.dart';
import 'package:workpulse/domain/repositories/idle_period_repository.dart';
import 'package:workpulse/domain/services/analytics_service.dart';

/// End-to-end cover for the pattern scan: real SQLite rows in, insights out.
/// The detector boundaries themselves are pinned in
/// work_pattern_service_test.dart, which needs no database at all.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AnalyticsService.getWorkPatternReport', () {
    late DatabaseService dbService;
    late SqliteSessionRepository sessionRepo;
    late SqliteWorkItemRepository workItemRepo;
    late SqliteIdlePeriodRepository idleRepo;
    late _CountingIdleRepository countingIdleRepo;
    late AnalyticsService analyticsService;

    const wsId = MigrationV1.defaultWorkspaceId;

    /// The moment every fixture is measured against — a Tuesday evening.
    final referenceTime = DateTime(2026, 8, 25, 18);

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      sessionRepo = SqliteSessionRepository(dbService);
      workItemRepo = SqliteWorkItemRepository(dbService);
      idleRepo = SqliteIdlePeriodRepository(dbService);
      countingIdleRepo = _CountingIdleRepository(idleRepo);

      analyticsService = AnalyticsService(
        sessionRepository: sessionRepo,
        workItemRepository: workItemRepo,
        projectRepository: SqliteProjectRepository(dbService),
        categoryRepository: SqliteCategoryRepository(dbService),
        tagRepository: SqliteTagRepository(dbService),
        personRepository: SqlitePersonRepository(dbService),
        attributeRepository: SqliteAttributeRepository(dbService),
        idlePeriodRepository: countingIdleRepo,
      );

      final created = DateTime.utc(2026, 7, 1);

      await SqliteProjectRepository(dbService).create(
        Project(
          id: 'proj-1',
          workspaceId: wsId,
          name: 'Platform',
          colorHex: '#0A84FF',
          createdAt: created,
          updatedAt: created,
        ),
      );
      await SqliteCategoryRepository(dbService).create(
        Category(
          id: 'cat-1',
          workspaceId: wsId,
          name: 'Status reporting',
          createdAt: created,
          updatedAt: created,
        ),
      );

      for (final id in ['routine', 'stalled']) {
        await workItemRepo.create(
          WorkItem(
            id: id,
            workspaceId: wsId,
            projectId: 'proj-1',
            categoryId: 'cat-1',
            name: id == 'routine' ? 'Weekly status pack' : 'Migration write-up',
            createdAt: created,
            updatedAt: created,
          ),
        );
      }
    });

    tearDown(() async {
      await dbService.close();
    });

    /// Local wall-clock in, UTC to storage — the same conversion the app does.
    Future<Session> track(
      String workItemId,
      DateTime localStart,
      Duration duration,
    ) {
      final start = localStart.toUtc();
      return sessionRepo.create(
        Session(
          id: 'sess-$workItemId-${localStart.toIso8601String()}',
          workItemId: workItemId,
          startTime: start,
          endTime: localStart.add(duration).toUtc(),
          createdAt: start,
        ),
      );
    }

    test('surfaces routine work to delegate and a commitment gone quiet',
        () async {
      // A short status pack, every working day for a fortnight.
      for (final day in [11, 12, 13, 14, 17, 18, 19, 20, 21, 24]) {
        await track(
          'routine',
          DateTime(2026, 8, day, 9),
          const Duration(minutes: 25),
        );
      }

      // Real investment early in the window, then silence.
      for (var i = 0; i < 3; i++) {
        await track(
          'stalled',
          DateTime(2026, 8, 10, 13 + (i * 2)),
          const Duration(minutes: 50),
        );
      }

      final report = await analyticsService.getWorkPatternReport(
        workspaceId: wsId,
        window: PatternWindow.oneMonth,
        referenceTime: referenceTime,
      );

      expect(report.hasData, isTrue);
      expect(report.sessionCount, 13);
      expect(report.totalActive, const Duration(hours: 6, minutes: 40));
      expect(report.lookback, PatternWindow.oneMonth);

      final delegate = report.forAction(InsightAction.delegate);
      expect(
        delegate.map((i) => i.id),
        contains('routine-task:routine'),
      );

      final atRisk = report
          .forAction(InsightAction.plan)
          .where((i) => i.id == 'at-risk:stalled');
      expect(atRisk, hasLength(1));
      expect(atRisk.single.title, contains('Migration write-up'));
      expect(atRisk.single.timeInvolved, const Duration(hours: 2, minutes: 30));
    });

    test('deducts idle time recorded against a session', () async {
      final session = await track(
        'routine',
        DateTime(2026, 8, 24, 9),
        const Duration(hours: 2),
      );

      await idleRepo.createIdlePeriod(
        IdlePeriod(
          id: 'idle-1',
          sessionId: session.id,
          startTime: session.startTime.add(const Duration(minutes: 30)),
          endTime: session.startTime.add(const Duration(minutes: 75)),
          resolution: IdleResolution.markIdle,
          createdAt: session.startTime,
        ),
      );

      final report = await analyticsService.getWorkPatternReport(
        workspaceId: wsId,
        window: PatternWindow.oneMonth,
        referenceTime: referenceTime,
      );

      expect(report.totalActive, const Duration(minutes: 75));
    });

    test('reads idle periods in one batched query, not one per session',
        () async {
      for (var day = 11; day <= 24; day++) {
        await track(
          'routine',
          DateTime(2026, 8, day, 9),
          const Duration(minutes: 30),
        );
      }
      countingIdleRepo.reset();

      final report = await analyticsService.getWorkPatternReport(
        workspaceId: wsId,
        window: PatternWindow.oneMonth,
        referenceTime: referenceTime,
      );

      expect(report.sessionCount, 14);
      expect(countingIdleRepo.batchedReads, 1);
      expect(countingIdleRepo.perSessionReads, isZero);
    });

    test('an empty window costs nothing and says nothing', () async {
      final report = await analyticsService.getWorkPatternReport(
        workspaceId: wsId,
        window: PatternWindow.twoWeeks,
        referenceTime: referenceTime,
      );

      expect(report.hasData, isFalse);
      expect(report.insights, isEmpty);
      expect(report.lookback, PatternWindow.twoWeeks);
      expect(countingIdleRepo.batchedReads, isZero);
    });

    test('a shorter window excludes what falls outside it', () async {
      await track('routine', DateTime(2026, 8, 5, 9), const Duration(hours: 1));
      await track(
          'routine', DateTime(2026, 8, 24, 9), const Duration(hours: 1));

      final quarter = await analyticsService.getWorkPatternReport(
        workspaceId: wsId,
        window: PatternWindow.oneQuarter,
        referenceTime: referenceTime,
      );
      final fortnight = await analyticsService.getWorkPatternReport(
        workspaceId: wsId,
        window: PatternWindow.twoWeeks,
        referenceTime: referenceTime,
      );

      expect(quarter.sessionCount, 2);
      expect(fortnight.sessionCount, 1);
    });
  });
}

/// Counts how the analytics path reaches for idle periods, so the batched read
/// cannot quietly regress into one query per session.
class _CountingIdleRepository implements IdlePeriodRepository {
  final IdlePeriodRepository _inner;

  int perSessionReads = 0;
  int batchedReads = 0;

  _CountingIdleRepository(this._inner);

  void reset() {
    perSessionReads = 0;
    batchedReads = 0;
  }

  @override
  Future<List<IdlePeriod>> getIdlePeriodsForSession(String sessionId) {
    perSessionReads++;
    return _inner.getIdlePeriodsForSession(sessionId);
  }

  @override
  Future<Map<String, List<IdlePeriod>>> getIdlePeriodsForSessions(
    List<String> sessionIds,
  ) {
    batchedReads++;
    return _inner.getIdlePeriodsForSessions(sessionIds);
  }

  @override
  Future<IdlePeriod?> getIdlePeriodById(String id) =>
      _inner.getIdlePeriodById(id);

  @override
  Future<void> createIdlePeriod(IdlePeriod idlePeriod) =>
      _inner.createIdlePeriod(idlePeriod);

  @override
  Future<void> updateIdlePeriod(IdlePeriod idlePeriod) =>
      _inner.updateIdlePeriod(idlePeriod);

  @override
  Future<void> deleteIdlePeriod(String id) => _inner.deleteIdlePeriod(id);
}
