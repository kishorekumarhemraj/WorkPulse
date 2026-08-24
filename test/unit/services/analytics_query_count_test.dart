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
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/repositories/attribute_repository.dart';
import 'package:workpulse/domain/services/analytics_service.dart';

/// The dashboard used to issue one `getWorkItemValues` query per
/// (reportable definition x session in range), re-reading the same rows over
/// and over. These tests pin the shape of the access pattern rather than a
/// wall-clock number, so they stay meaningful on any machine.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Dashboard query volume', () {
    late DatabaseService dbService;
    late SqliteSessionRepository sessionRepo;
    late SqliteWorkItemRepository workItemRepo;
    late SqliteAttributeRepository attributeRepo;
    late _CountingAttributeRepository countingAttributeRepo;
    late AnalyticsService analyticsService;

    const wsId = MigrationV1.defaultWorkspaceId;
    const workItemCount = 4;
    const sessionsPerWorkItem = 5;
    const reportableDefinitionCount = 3;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      sessionRepo = SqliteSessionRepository(dbService);
      workItemRepo = SqliteWorkItemRepository(dbService);
      attributeRepo = SqliteAttributeRepository(dbService);
      countingAttributeRepo = _CountingAttributeRepository(attributeRepo);

      analyticsService = AnalyticsService(
        sessionRepository: sessionRepo,
        workItemRepository: workItemRepo,
        projectRepository: SqliteProjectRepository(dbService),
        categoryRepository: SqliteCategoryRepository(dbService),
        tagRepository: SqliteTagRepository(dbService),
        personRepository: SqlitePersonRepository(dbService),
        attributeRepository: countingAttributeRepo,
        idlePeriodRepository: SqliteIdlePeriodRepository(dbService),
      );

      final now = DateTime.utc(2026, 8, 23, 12);

      final project = await SqliteProjectRepository(dbService).create(
        Project(
          id: 'proj-1',
          workspaceId: wsId,
          name: 'Perf',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final category = await SqliteCategoryRepository(dbService).create(
        Category(
          id: 'cat-1',
          workspaceId: wsId,
          name: 'Dev',
          createdAt: now,
          updatedAt: now,
        ),
      );

      for (var d = 0; d < reportableDefinitionCount; d++) {
        await attributeRepo.createDefinition(
          AttributeDefinition(
            id: 'attr-$d',
            workspaceId: wsId,
            key: 'flag_$d',
            name: 'Flag $d',
            type: AttributeType.boolean,
            scope: AttributeScope.task,
            reportable: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      for (var w = 0; w < workItemCount; w++) {
        final item = await workItemRepo.create(
          WorkItem(
            id: 'task-$w',
            workspaceId: wsId,
            projectId: project.id,
            categoryId: category.id,
            name: 'Task $w',
            createdAt: now,
            updatedAt: now,
          ),
        );

        for (var d = 0; d < reportableDefinitionCount; d++) {
          await attributeRepo.setWorkItemValue(
            WorkItemAttributeValue(
              id: 'val-$w-$d',
              workItemId: item.id,
              attributeDefinitionId: 'attr-$d',
              booleanValue: w.isEven,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }

        for (var i = 0; i < sessionsPerWorkItem; i++) {
          final start = now.add(Duration(minutes: (w * 60) + (i * 10)));
          await sessionRepo.create(
            Session(
              id: 'sess-$w-$i',
              workItemId: item.id,
              startTime: start,
              endTime: start.add(const Duration(minutes: 5)),
              createdAt: start,
            ),
          );
        }
      }

      countingAttributeRepo.reset();
    });

    tearDown(() async {
      await dbService.close();
    });

    test('reads each work item\'s attribute values exactly once', () async {
      final data = await analyticsService.getDashboardData(
        workspaceId: wsId,
        range: DateRange(
          start: DateTime.utc(2026, 8, 23),
          end: DateTime.utc(2026, 8, 23, 23, 59, 59),
        ),
      );

      // Sanity: the run really did cover every session.
      expect(data.summary.sessionCount, workItemCount * sessionsPerWorkItem);
      expect(data.attributeBreakdowns, hasLength(reportableDefinitionCount));

      // The old code did definitions x sessions = 3 x 20 = 60 reads of the
      // same rows. One per distinct work item is the floor.
      expect(countingAttributeRepo.workItemValueReads, workItemCount);
      expect(
        countingAttributeRepo.readWorkItemIds.toSet(),
        {for (var w = 0; w < workItemCount; w++) 'task-$w'},
      );
    });
  });

  group('SqliteSessionRepository batching', () {
    late DatabaseService dbService;
    late SqliteSessionRepository sessionRepo;

    const wsId = MigrationV1.defaultWorkspaceId;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);
      sessionRepo = SqliteSessionRepository(dbService);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('hydrates people and tags for a whole range correctly', () async {
      final now = DateTime.utc(2026, 8, 23, 9);

      final project = await SqliteProjectRepository(dbService).create(
        Project(
          id: 'proj-1',
          workspaceId: wsId,
          name: 'Batch',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final category = await SqliteCategoryRepository(dbService).create(
        Category(
          id: 'cat-1',
          workspaceId: wsId,
          name: 'Dev',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final item = await SqliteWorkItemRepository(dbService).create(
        WorkItem(
          id: 'task-1',
          workspaceId: wsId,
          projectId: project.id,
          categoryId: category.id,
          name: 'Batch',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final personRepo = SqlitePersonRepository(dbService);
      final tagRepo = SqliteTagRepository(dbService);
      final alice = await personRepo.create(_person('p-1', 'Alice', now));
      final bob = await personRepo.create(_person('p-2', 'Bob', now));
      final urgent = await tagRepo.create(_tag('t-1', 'urgent', now));

      // A session with both, a session with only tags, and a bare one: the
      // grouped lookup has to keep them apart.
      await sessionRepo.create(Session(
        id: 'sess-both',
        workItemId: item.id,
        startTime: now,
        endTime: now.add(const Duration(minutes: 10)),
        peopleIds: [alice.id, bob.id],
        tagIds: [urgent.id],
        createdAt: now,
      ));
      await sessionRepo.create(Session(
        id: 'sess-tag-only',
        workItemId: item.id,
        startTime: now.add(const Duration(minutes: 20)),
        endTime: now.add(const Duration(minutes: 30)),
        tagIds: [urgent.id],
        createdAt: now,
      ));
      await sessionRepo.create(Session(
        id: 'sess-bare',
        workItemId: item.id,
        startTime: now.add(const Duration(minutes: 40)),
        endTime: now.add(const Duration(minutes: 50)),
        createdAt: now,
      ));

      final sessions = await sessionRepo.getByDateRange(
        DateTime.utc(2026, 8, 23),
        DateTime.utc(2026, 8, 23, 23, 59, 59),
      );
      final byId = {for (final s in sessions) s.id: s};

      expect(sessions, hasLength(3));
      expect(byId['sess-both']!.peopleIds, unorderedEquals([alice.id, bob.id]));
      expect(byId['sess-both']!.tagIds, [urgent.id]);
      expect(byId['sess-tag-only']!.peopleIds, isEmpty);
      expect(byId['sess-tag-only']!.tagIds, [urgent.id]);
      expect(byId['sess-bare']!.peopleIds, isEmpty);
      expect(byId['sess-bare']!.tagIds, isEmpty);
    });

    test('an empty range returns nothing without querying join tables',
        () async {
      final sessions = await sessionRepo.getByDateRange(
        DateTime.utc(2020),
        DateTime.utc(2020, 1, 2),
      );
      expect(sessions, isEmpty);
    });
  });
}

/// Counts how often work item attribute values are read, delegating
/// everything else to the real repository.
class _CountingAttributeRepository implements AttributeRepository {
  final AttributeRepository _inner;
  int workItemValueReads = 0;
  final readWorkItemIds = <String>[];

  _CountingAttributeRepository(this._inner);

  void reset() {
    workItemValueReads = 0;
    readWorkItemIds.clear();
  }

  @override
  Future<List<WorkItemAttributeValue>> getWorkItemValues(String workItemId) {
    workItemValueReads++;
    readWorkItemIds.add(workItemId);
    return _inner.getWorkItemValues(workItemId);
  }

  @override
  Future<AttributeDefinition?> getDefinitionById(String id) =>
      _inner.getDefinitionById(id);

  @override
  Future<AttributeDefinition?> getDefinitionByKey(
          String workspaceId, String key) =>
      _inner.getDefinitionByKey(workspaceId, key);

  @override
  Future<List<AttributeDefinition>> getDefinitions({
    String? workspaceId,
    AttributeScope? scope,
    bool includeArchived = false,
  }) =>
      _inner.getDefinitions(
        workspaceId: workspaceId,
        scope: scope,
        includeArchived: includeArchived,
      );

  @override
  Future<AttributeDefinition> createDefinition(AttributeDefinition d) =>
      _inner.createDefinition(d);

  @override
  Future<AttributeDefinition> updateDefinition(AttributeDefinition d) =>
      _inner.updateDefinition(d);

  @override
  Future<void> archiveDefinition(String id) => _inner.archiveDefinition(id);

  @override
  Future<void> deleteDefinition(String id) => _inner.deleteDefinition(id);

  @override
  Future<List<AttributeOption>> getOptions(String definitionId,
          {bool includeArchived = false}) =>
      _inner.getOptions(definitionId, includeArchived: includeArchived);

  @override
  Future<AttributeOption> createOption(AttributeOption option) =>
      _inner.createOption(option);

  @override
  Future<AttributeOption> updateOption(AttributeOption option) =>
      _inner.updateOption(option);

  @override
  Future<void> archiveOption(String id) => _inner.archiveOption(id);

  @override
  Future<void> deleteOption(String id) => _inner.deleteOption(id);

  @override
  Future<void> setWorkItemValue(WorkItemAttributeValue value) =>
      _inner.setWorkItemValue(value);

  @override
  Future<void> deleteWorkItemValue(String valueId) =>
      _inner.deleteWorkItemValue(valueId);

  @override
  Future<void> deleteWorkItemValuesByWorkItemId(String workItemId) =>
      _inner.deleteWorkItemValuesByWorkItemId(workItemId);

  @override
  Future<List<SessionAttributeValue>> getSessionValues(String sessionId) =>
      _inner.getSessionValues(sessionId);

  @override
  Future<void> setSessionValue(SessionAttributeValue value) =>
      _inner.setSessionValue(value);

  @override
  Future<void> deleteSessionValue(String valueId) =>
      _inner.deleteSessionValue(valueId);

  @override
  Future<void> deleteSessionValuesBySessionId(String sessionId) =>
      _inner.deleteSessionValuesBySessionId(sessionId);
}

Person _person(String id, String name, DateTime now) => Person(
      id: id,
      workspaceId: MigrationV1.defaultWorkspaceId,
      name: name,
      createdAt: now,
    );

Tag _tag(String id, String name, DateTime now) => Tag(
      id: id,
      workspaceId: MigrationV1.defaultWorkspaceId,
      name: name,
      createdAt: now,
    );
