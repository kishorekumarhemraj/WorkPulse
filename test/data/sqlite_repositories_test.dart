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
import 'package:workpulse/data/repositories/sqlite_settings_repository.dart';
import 'package:workpulse/data/repositories/sqlite_tag_repository.dart';
import 'package:workpulse/data/repositories/sqlite_work_item_repository.dart';
import 'package:workpulse/data/repositories/sqlite_workspace_repository.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/workspace_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SQLite Repositories End-to-End Tests', () {
    late DatabaseService dbService;
    late SqliteWorkspaceRepository workspaceRepo;
    late SqliteProjectRepository projectRepo;
    late SqliteCategoryRepository categoryRepo;
    late SqliteTagRepository tagRepo;
    late SqlitePersonRepository personRepo;
    late SqliteWorkItemRepository workItemRepo;
    late SqliteSessionRepository sessionRepo;
    late SqliteAttributeRepository attributeRepo;
    late SqliteIdlePeriodRepository idleRepo;
    late SqliteSettingsRepository settingsRepo;

    const wsId = MigrationV1.defaultWorkspaceId;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      workspaceRepo = SqliteWorkspaceRepository(dbService);
      projectRepo = SqliteProjectRepository(dbService);
      categoryRepo = SqliteCategoryRepository(dbService);
      tagRepo = SqliteTagRepository(dbService);
      personRepo = SqlitePersonRepository(dbService);
      workItemRepo = SqliteWorkItemRepository(dbService);
      sessionRepo = SqliteSessionRepository(dbService);
      attributeRepo = SqliteAttributeRepository(dbService);
      idleRepo = SqliteIdlePeriodRepository(dbService);
      settingsRepo = SqliteSettingsRepository(dbService);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('Workspace repository operations', () async {
      final defaultWs = await workspaceRepo.getById(wsId);
      expect(defaultWs, isNotNull);
      expect(defaultWs!.name, equals('Default'));

      final customWs = Workspace(
        id: 'ws-custom',
        name: 'OpenText',
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
        updatedAt: DateTime.utc(2026, 8, 23, 10, 0),
      );
      await workspaceRepo.create(customWs);

      final all = await workspaceRepo.getAll();
      expect(all.length, equals(2));
    });

    test('Project & Category CRUD operations with archiving', () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      final project = Project(
        id: 'proj-1',
        workspaceId: wsId,
        name: 'WorkPulse Core',
        description: 'Core backend platform',
        colorHex: '#0A84FF',
        createdAt: now,
        updatedAt: now,
      );
      await projectRepo.create(project);

      final fetchedProj = await projectRepo.getById('proj-1');
      expect(fetchedProj, isNotNull);
      expect(fetchedProj!.name, equals('WorkPulse Core'));

      final category = Category(
        id: 'cat-1',
        workspaceId: wsId,
        name: 'Engineering',
        description: 'Software development',
        iconName: 'code',
        createdAt: now,
        updatedAt: now,
      );
      await categoryRepo.create(category);

      final allCats = await categoryRepo.getAll(workspaceId: wsId);
      expect(allCats.length, equals(1));
      expect(allCats.first.id, equals('cat-1'));

      // Test archiving
      await projectRepo.archive('proj-1');
      final activeProjects = await projectRepo.getAll(workspaceId: wsId, includeArchived: false);
      expect(activeProjects.isEmpty, isTrue);

      final allProjects = await projectRepo.getAll(workspaceId: wsId, includeArchived: true);
      expect(allProjects.length, equals(1));
      expect(allProjects.first.isArchived, isTrue);
    });

    test('Tags & People relations and CRUD', () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      final tag1 = Tag(id: 'tag-1', workspaceId: wsId, name: 'Architecture', createdAt: now);
      final tag2 = Tag(id: 'tag-2', workspaceId: wsId, name: 'Deep Work', createdAt: now);
      await tagRepo.create(tag1);
      await tagRepo.create(tag2);

      final allTags = await tagRepo.getAll(workspaceId: wsId);
      expect(allTags.length, equals(2));

      final person = Person(id: 'per-1', workspaceId: wsId, name: 'Richard', email: 'r@example.com', createdAt: now);
      await personRepo.create(person);

      final fetchedPerson = await personRepo.getById('per-1');
      expect(fetchedPerson?.name, equals('Richard'));
    });

    test('WorkItem creation, search, and relations', () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      // Seed project, category, tag, person
      await projectRepo.create(Project(
        id: 'p-1',
        workspaceId: wsId,
        name: 'WorkPulse Core',
        createdAt: now,
        updatedAt: now,
      ));
      await categoryRepo.create(Category(
        id: 'c-1',
        workspaceId: wsId,
        name: 'Engineering',
        createdAt: now,
        updatedAt: now,
      ));
      await tagRepo.create(Tag(id: 't-1', workspaceId: wsId, name: 'Deep Work', createdAt: now));
      await personRepo.create(Person(id: 'per-1', workspaceId: wsId, name: 'Richard', createdAt: now));

      // Create work item
      final workItem = WorkItem(
        id: 'wi-1',
        workspaceId: wsId,
        name: 'Prepare Q3 architecture proposal',
        projectId: 'p-1',
        categoryId: 'c-1',
        notes: 'Spec compliance sprint',
        tagIds: const ['t-1'],
        peopleIds: const ['per-1'],
        createdAt: now,
        updatedAt: now,
      );
      await workItemRepo.create(workItem);

      // Verify work item retrieval with populated relations
      final retrieved = await workItemRepo.getById('wi-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Prepare Q3 architecture proposal'));
      expect(retrieved.tagIds, contains('t-1'));
      expect(retrieved.peopleIds, contains('per-1'));

      // Verify search
      final searchResults = await workItemRepo.search('architecture', workspaceId: wsId);
      expect(searchResults.length, equals(1));
      expect(searchResults.first.id, equals('wi-1'));

      // Verify recent
      final recent = await workItemRepo.getRecent(workspaceId: wsId);
      expect(recent.length, equals(1));
      expect(recent.first.id, equals('wi-1'));
    });

    test('Configurable Attributes definition, options, and values lifecycle', () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      // 1. Create AttributeDefinition for Jira ID (configurable, zero hardcoded in domain)
      final jiraDef = AttributeDefinition(
        id: 'attr-jira',
        workspaceId: wsId,
        key: 'jira_id',
        name: 'Jira ID',
        type: AttributeType.text,
        scope: AttributeScope.task,
        required: false,
        createdAt: now,
        updatedAt: now,
      );
      await attributeRepo.createDefinition(jiraDef);

      final fetchedDef = await attributeRepo.getDefinitionByKey(wsId, 'jira_id');
      expect(fetchedDef, isNotNull);
      expect(fetchedDef!.name, equals('Jira ID'));
      expect(fetchedDef.type, equals(AttributeType.text));

      // 2. Create Single Select AttributeDefinition with Options
      final envDef = AttributeDefinition(
        id: 'attr-env',
        workspaceId: wsId,
        key: 'environment',
        name: 'Environment',
        type: AttributeType.singleSelect,
        scope: AttributeScope.task,
        createdAt: now,
        updatedAt: now,
      );
      await attributeRepo.createDefinition(envDef);

      final optDev = AttributeOption(
        id: 'opt-dev',
        attributeDefinitionId: 'attr-env',
        value: 'dev',
        label: 'Development',
        displayOrder: 0,
        createdAt: now,
      );
      final optProd = AttributeOption(
        id: 'opt-prod',
        attributeDefinitionId: 'attr-env',
        value: 'prod',
        label: 'Production',
        displayOrder: 1,
        createdAt: now,
      );
      await attributeRepo.createOption(optDev);
      await attributeRepo.createOption(optProd);

      final options = await attributeRepo.getOptions('attr-env');
      expect(options.length, equals(2));
      expect(options.first.label, equals('Development'));

      // 3. Attach values to WorkItem
      await projectRepo.create(Project(id: 'p-1', workspaceId: wsId, name: 'P', createdAt: now, updatedAt: now));
      await categoryRepo.create(Category(id: 'c-1', workspaceId: wsId, name: 'C', createdAt: now, updatedAt: now));
      await workItemRepo.create(WorkItem(id: 'wi-1', workspaceId: wsId, name: 'Task 1', projectId: 'p-1', categoryId: 'c-1', createdAt: now, updatedAt: now));

      final jiraVal = WorkItemAttributeValue(
        id: 'val-1',
        workItemId: 'wi-1',
        attributeDefinitionId: 'attr-jira',
        textValue: 'PROD-1234',
        createdAt: now,
        updatedAt: now,
      );
      await attributeRepo.setWorkItemValue(jiraVal);

      final wiValues = await attributeRepo.getWorkItemValues('wi-1');
      expect(wiValues.length, equals(1));
      expect(wiValues.first.textValue, equals('PROD-1234'));
    });

    test('Session lifecycle, active session recovery, and multi-session resume', () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      // Setup work item
      await projectRepo.create(Project(id: 'p-1', workspaceId: wsId, name: 'WorkPulse', createdAt: now, updatedAt: now));
      await categoryRepo.create(Category(id: 'c-1', workspaceId: wsId, name: 'Dev', createdAt: now, updatedAt: now));
      await workItemRepo.create(WorkItem(
        id: 'wi-1',
        workspaceId: wsId,
        name: 'API Redesign',
        projectId: 'p-1',
        categoryId: 'c-1',
        createdAt: now,
        updatedAt: now,
      ));

      // Session 1: completed
      final session1 = Session(
        id: 'sess-1',
        workItemId: 'wi-1',
        startTime: DateTime.utc(2026, 8, 23, 10, 0),
        endTime: DateTime.utc(2026, 8, 23, 11, 15),
        createdAt: now,
      );
      await sessionRepo.create(session1);

      // No active session yet
      var active = await sessionRepo.getActiveSession();
      expect(active, isNull);

      // Session 2: active (ongoing)
      final session2 = Session(
        id: 'sess-2',
        workItemId: 'wi-1',
        startTime: DateTime.utc(2026, 8, 23, 14, 0),
        endTime: null,
        createdAt: DateTime.utc(2026, 8, 23, 14, 0),
      );
      await sessionRepo.create(session2);

      // Active session recovery check
      active = await sessionRepo.getActiveSession();
      expect(active, isNotNull);
      expect(active!.id, equals('sess-2'));
      expect(active.isActive, isTrue);

      // End active session
      await sessionRepo.update(session2.copyWith(endTime: DateTime.utc(2026, 8, 23, 15, 0)));
      active = await sessionRepo.getActiveSession();
      expect(active, isNull);

      // Verify all sessions for work item
      final itemSessions = await sessionRepo.getByWorkItemId('wi-1');
      expect(itemSessions.length, equals(2));
      final totalMinutes = itemSessions.fold<int>(0, (sum, s) => sum + s.duration.inMinutes);
      expect(totalMinutes, equals(75 + 60)); // 135 mins = 2h 15m
    });

    test('Idle period recording and settings persistence', () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      // Setup work item & session
      await projectRepo.create(Project(id: 'p-1', workspaceId: wsId, name: 'P', createdAt: now, updatedAt: now));
      await categoryRepo.create(Category(id: 'c-1', workspaceId: wsId, name: 'C', createdAt: now, updatedAt: now));
      await workItemRepo.create(WorkItem(id: 'wi-1', workspaceId: wsId, name: 'T', projectId: 'p-1', categoryId: 'c-1', createdAt: now, updatedAt: now));
      await sessionRepo.create(Session(id: 's-1', workItemId: 'wi-1', startTime: now, createdAt: now));

      // Add idle period
      final idle = IdlePeriod(
        id: 'idle-1',
        sessionId: 's-1',
        startTime: DateTime.utc(2026, 8, 23, 10, 15),
        endTime: DateTime.utc(2026, 8, 23, 10, 45),
        resolution: IdleResolution.markIdle,
        createdAt: now,
      );
      await idleRepo.createIdlePeriod(idle);

      final idles = await idleRepo.getIdlePeriodsForSession('s-1');
      expect(idles.length, equals(1));
      expect(idles.first.resolution, equals(IdleResolution.markIdle));

      // Settings
      await settingsRepo.setSetting('global_hotkey', 'Option + Space');
      final hotkey = await settingsRepo.getSetting('global_hotkey');
      expect(hotkey, equals('Option + Space'));
    });
  });
}
