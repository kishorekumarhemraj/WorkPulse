import 'dart:convert';
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
import 'package:workpulse/data/repositories/sqlite_workspace_repository.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/export_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ExportService Unit Tests (CSV & JSON)', () {
    late DatabaseService dbService;
    late SqliteWorkspaceRepository workspaceRepo;
    late SqliteSessionRepository sessionRepo;
    late SqliteWorkItemRepository workItemRepo;
    late SqliteProjectRepository projectRepo;
    late SqliteCategoryRepository categoryRepo;
    late SqliteTagRepository tagRepo;
    late SqlitePersonRepository personRepo;
    late SqliteAttributeRepository attributeRepo;
    late SqliteIdlePeriodRepository idleRepo;
    late ExportService exportService;

    const wsId = MigrationV1.defaultWorkspaceId;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      workspaceRepo = SqliteWorkspaceRepository(dbService);
      sessionRepo = SqliteSessionRepository(dbService);
      workItemRepo = SqliteWorkItemRepository(dbService);
      projectRepo = SqliteProjectRepository(dbService);
      categoryRepo = SqliteCategoryRepository(dbService);
      tagRepo = SqliteTagRepository(dbService);
      personRepo = SqlitePersonRepository(dbService);
      attributeRepo = SqliteAttributeRepository(dbService);
      idleRepo = SqliteIdlePeriodRepository(dbService);

      exportService = ExportService(
        workspaceRepository: workspaceRepo,
        sessionRepository: sessionRepo,
        workItemRepository: workItemRepo,
        projectRepository: projectRepo,
        categoryRepository: categoryRepo,
        tagRepository: tagRepo,
        personRepository: personRepo,
        attributeRepository: attributeRepo,
        idlePeriodRepository: idleRepo,
      );

      final now = DateTime.utc(2026, 8, 23, 10, 0, 0);

      // Seed Project & Category
      final proj = await projectRepo.create(
        Project(
            id: 'proj-1',
            workspaceId: wsId,
            name: 'Client "Acme" Project, Inc.',
            colorHex: '#0A84FF',
            createdAt: now,
            updatedAt: now),
      );

      final cat = await categoryRepo.create(
        Category(
            id: 'cat-1',
            workspaceId: wsId,
            name: 'Development',
            iconName: 'code',
            createdAt: now,
            updatedAt: now),
      );

      // Seed Tag & Person
      final tag = await tagRepo.create(
        Tag(
            id: 'tag-1',
            workspaceId: wsId,
            name: 'Frontend',
            colorHex: '#30D158',
            createdAt: now),
      );

      final person = await personRepo.create(
        Person(
            id: 'person-1',
            workspaceId: wsId,
            name: 'John Doe',
            createdAt: now),
      );

      // Seed Custom Attribute (Billing Rate & Ticket ID)
      final rateDef = await attributeRepo.createDefinition(
        AttributeDefinition(
          id: 'attr-rate',
          workspaceId: wsId,
          key: 'billing_rate',
          name: 'Billing Rate',
          type: AttributeType.number,
          scope: AttributeScope.task,
          enabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed Work Item
      final task = await workItemRepo.create(
        WorkItem(
          id: 'task-1',
          workspaceId: wsId,
          projectId: proj.id,
          categoryId: cat.id,
          name: 'Build Export Feature',
          notes: 'Important task notes with, comma',
          tagIds: [tag.id],
          peopleIds: [person.id],
          createdAt: now,
          updatedAt: now,
        ),
      );

      await attributeRepo.setWorkItemValue(
        WorkItemAttributeValue(
          id: 'val-1',
          workItemId: task.id,
          attributeDefinitionId: rateDef.id,
          numberValue: 150.0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed Session: 60 minutes with 10 min idle -> 50 min net
      final sessStart = now.subtract(const Duration(hours: 2));
      final sessEnd = sessStart.add(const Duration(minutes: 60));

      final sess = await sessionRepo.create(
        Session(
          id: 'sess-1',
          workItemId: task.id,
          startTime: sessStart,
          endTime: sessEnd,
          peopleIds: [person.id],
          createdAt: sessStart,
        ),
      );

      await idleRepo.createIdlePeriod(
        IdlePeriod(
          id: 'idle-1',
          sessionId: sess.id,
          startTime: sessStart.add(const Duration(minutes: 20)),
          endTime: sessStart.add(const Duration(minutes: 30)),
          resolution: IdleResolution.markIdle,
          createdAt: sessStart.add(const Duration(minutes: 30)),
        ),
      );
    });

    tearDown(() async {
      await dbService.close();
    });

    test(
        'generateCsv outputs RFC 4180 compliant CSV with dynamic attribute columns and proper escaping',
        () async {
      final range = DateRange(
        start: DateTime.utc(2026, 8, 23, 0, 0, 0),
        end: DateTime.utc(2026, 8, 23, 23, 59, 59),
      );

      final csv =
          await exportService.generateCsv(workspaceId: wsId, range: range);

      expect(csv, isNotEmpty);
      final lines = csv.trim().split('\n');
      expect(lines.length, 2); // Header + 1 Data Row

      final headerLine = lines[0];
      expect(headerLine, contains('Date'));
      expect(headerLine, contains('Gross Duration'));
      expect(headerLine, contains('Net Duration'));
      expect(headerLine, contains('Billing Rate'));

      final dataLine = lines[1];
      expect(
          dataLine,
          contains(
              '"Client ""Acme"" Project, Inc."')); // Escaped quotes and comma
      expect(dataLine, contains('Development'));
      expect(dataLine, contains('Build Export Feature'));
      expect(dataLine, contains('Frontend'));
      expect(dataLine, contains('John Doe'));
      expect(dataLine, contains('01:00:00')); // Gross
      expect(dataLine, contains('00:10:00')); // Idle
      expect(dataLine, contains('00:50:00')); // Net active
      expect(dataLine, contains('150')); // Billing rate value
    });

    test(
        'generateJson outputs structured hierarchical backup with complete metadata',
        () async {
      final range = DateRange(
        start: DateTime.utc(2026, 8, 23, 0, 0, 0),
        end: DateTime.utc(2026, 8, 23, 23, 59, 59),
      );

      final jsonStr =
          await exportService.generateJson(workspaceId: wsId, range: range);
      expect(jsonStr, isNotEmpty);

      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      expect(decoded['version'], '1.0.0');
      expect(decoded['workspace']['id'], wsId);
      expect(decoded['summary']['sessionCount'], 1);
      expect(decoded['summary']['totalGrossDurationSeconds'], 3600);
      expect(decoded['summary']['totalIdleDurationSeconds'], 600);
      expect(decoded['summary']['totalNetDurationSeconds'], 3000);

      final sessions = decoded['sessions'] as List;
      expect(sessions.length, 1);

      final firstSession = sessions[0] as Map<String, dynamic>;
      expect(firstSession['workItem']['name'], 'Build Export Feature');
      expect(firstSession['project']['name'], 'Client "Acme" Project, Inc.');
      expect(firstSession['category']['name'], 'Development');
      expect(firstSession['tags'][0]['name'], 'Frontend');
      expect(firstSession['people'][0]['name'], 'John Doe');
      expect(firstSession['idlePeriods'].length, 1);
      expect(firstSession['idlePeriods'][0]['durationSeconds'], 600);
    });
  });
}
