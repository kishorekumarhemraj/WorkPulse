import 'package:flutter/material.dart';
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
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/analytics_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AnalyticsService SQLite Aggregation Unit Tests', () {
    late DatabaseService dbService;
    late SqliteSessionRepository sessionRepo;
    late SqliteWorkItemRepository workItemRepo;
    late SqliteProjectRepository projectRepo;
    late SqliteCategoryRepository categoryRepo;
    late SqliteTagRepository tagRepo;
    late SqlitePersonRepository personRepo;
    late SqliteAttributeRepository attributeRepo;
    late SqliteIdlePeriodRepository idleRepo;
    late AnalyticsService analyticsService;

    const wsId = MigrationV1.defaultWorkspaceId;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      sessionRepo = SqliteSessionRepository(dbService);
      workItemRepo = SqliteWorkItemRepository(dbService);
      projectRepo = SqliteProjectRepository(dbService);
      categoryRepo = SqliteCategoryRepository(dbService);
      tagRepo = SqliteTagRepository(dbService);
      personRepo = SqlitePersonRepository(dbService);
      attributeRepo = SqliteAttributeRepository(dbService);
      idleRepo = SqliteIdlePeriodRepository(dbService);

      analyticsService = AnalyticsService(
        sessionRepository: sessionRepo,
        workItemRepository: workItemRepo,
        projectRepository: projectRepo,
        categoryRepository: categoryRepo,
        tagRepository: tagRepo,
        personRepository: personRepo,
        attributeRepository: attributeRepo,
        idlePeriodRepository: idleRepo,
      );
    });

    tearDown(() async {
      await dbService.close();
    });

    test('getDashboardData aggregates multi-dimensional time tracking with idle deductions', () async {
      final now = DateTime.utc(2026, 8, 23, 12, 0, 0);

      // 1. Seed Projects & Categories
      final projAlpha = await projectRepo.create(
        Project(id: 'proj-alpha', workspaceId: wsId, name: 'Alpha Project', colorHex: '#0A84FF', createdAt: now, updatedAt: now),
      );
      final projBeta = await projectRepo.create(
        Project(id: 'proj-beta', workspaceId: wsId, name: 'Beta Project', colorHex: '#30D158', createdAt: now, updatedAt: now),
      );

      final catDev = await categoryRepo.create(
        Category(id: 'cat-dev', workspaceId: wsId, name: 'Development', iconName: 'code', createdAt: now, updatedAt: now),
      );
      final catDesign = await categoryRepo.create(
        Category(id: 'cat-design', workspaceId: wsId, name: 'Design', iconName: 'brush', createdAt: now, updatedAt: now),
      );

      // 2. Seed Tag & Person
      final tagUrgent = await tagRepo.create(
        Tag(id: 'tag-urgent', workspaceId: wsId, name: 'Urgent', colorHex: '#FF453A', createdAt: now),
      );
      final personAlice = await personRepo.create(
        Person(id: 'person-alice', workspaceId: wsId, name: 'Alice Smith', createdAt: now),
      );

      // 3. Seed Work Items
      final task1 = await workItemRepo.create(
        WorkItem(
          id: 'task-1',
          workspaceId: wsId,
          projectId: projAlpha.id,
          categoryId: catDev.id,
          name: 'Task 1 Backend',
          tagIds: [tagUrgent.id],
          peopleIds: [personAlice.id],
          createdAt: now,
          updatedAt: now,
        ),
      );

      final task2 = await workItemRepo.create(
        WorkItem(
          id: 'task-2',
          workspaceId: wsId,
          projectId: projBeta.id,
          categoryId: catDesign.id,
          name: 'Task 2 UI Mockups',
          tagIds: [],
          peopleIds: [],
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 4. Seed Attribute Definition (Billable Boolean) & Value
      final billableDef = await attributeRepo.createDefinition(
        AttributeDefinition(
          id: 'attr-billable',
          workspaceId: wsId,
          key: 'billable',
          name: 'Is Billable',
          type: AttributeType.boolean,
          scope: AttributeScope.task,
          reportable: true,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await attributeRepo.setWorkItemValue(
        WorkItemAttributeValue(
          id: 'val-1',
          workItemId: task1.id,
          attributeDefinitionId: billableDef.id,
          booleanValue: true,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 5. Seed Sessions
      // Session 1 on Task 1: 60 minutes (with 15 min idle) -> 45 min net active
      final sess1Start = now.subtract(const Duration(hours: 3));
      final sess1End = sess1Start.add(const Duration(minutes: 60));
      final sess1 = await sessionRepo.create(
        Session(
          id: 'sess-1',
          workItemId: task1.id,
          startTime: sess1Start,
          endTime: sess1End,
          peopleIds: [personAlice.id],
          createdAt: sess1Start,
        ),
      );

      await idleRepo.createIdlePeriod(
        IdlePeriod(
          id: 'idle-1',
          sessionId: sess1.id,
          startTime: sess1Start.add(const Duration(minutes: 30)),
          endTime: sess1Start.add(const Duration(minutes: 45)),
          resolution: IdleResolution.markIdle,
          createdAt: sess1Start.add(const Duration(minutes: 45)),
        ),
      );

      // Session 2 on Task 2: 30 minutes (0 min idle) -> 30 min net active
      final sess2Start = now.subtract(const Duration(hours: 1));
      final sess2End = sess2Start.add(const Duration(minutes: 30));
      await sessionRepo.create(
        Session(
          id: 'sess-2',
          workItemId: task2.id,
          startTime: sess2Start,
          endTime: sess2End,
          createdAt: sess2Start,
        ),
      );

      // 6. Query Dashboard Data
      final range = DateTimeRange(
        start: DateTime.utc(2026, 8, 23, 0, 0, 0),
        end: DateTime.utc(2026, 8, 23, 23, 59, 59),
      );

      final data = await analyticsService.getDashboardData(
        workspaceId: wsId,
        range: range,
      );

      // Summary assertions
      expect(data.summary.totalTrackedDuration, const Duration(minutes: 90));
      expect(data.summary.totalIdleDuration, const Duration(minutes: 15));
      expect(data.summary.totalActiveDuration, const Duration(minutes: 75)); // 45 + 30
      expect(data.summary.sessionCount, 2);
      expect(data.summary.taskCount, 2);

      // Project Breakdown assertions
      expect(data.projectBreakdown.length, 2);
      final alphaProj = data.projectBreakdown.firstWhere((p) => p.id == projAlpha.id);
      expect(alphaProj.duration, const Duration(minutes: 45));
      expect(alphaProj.percentage, closeTo(60.0, 0.1)); // 45/75 = 60%

      final betaProj = data.projectBreakdown.firstWhere((p) => p.id == projBeta.id);
      expect(betaProj.duration, const Duration(minutes: 30));
      expect(betaProj.percentage, closeTo(40.0, 0.1)); // 30/75 = 40%

      // Category Breakdown assertions
      expect(data.categoryBreakdown.length, 2);
      final devCat = data.categoryBreakdown.firstWhere((c) => c.id == catDev.id);
      expect(devCat.duration, const Duration(minutes: 45));

      // Tag Breakdown assertions
      expect(data.tagBreakdown.length, 1);
      expect(data.tagBreakdown.first.id, tagUrgent.id);
      expect(data.tagBreakdown.first.duration, const Duration(minutes: 45));

      // Person Breakdown assertions
      expect(data.personBreakdown.length, 1);
      expect(data.personBreakdown.first.id, personAlice.id);
      expect(data.personBreakdown.first.duration, const Duration(minutes: 45));

      // Attribute Breakdown assertions
      expect(data.attributeBreakdowns.length, 1);
      final billableGroup = data.attributeBreakdowns.first;
      expect(billableGroup.definition.key, 'billable');
      expect(billableGroup.items.length, 1);
      expect(billableGroup.items.first.name, 'Yes');
      expect(billableGroup.items.first.duration, const Duration(minutes: 45));
    });
  });
}
