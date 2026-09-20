import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';
import 'package:workpulse/data/repositories/sqlite_attribute_repository.dart';
import 'package:workpulse/data/repositories/sqlite_category_repository.dart';
import 'package:workpulse/data/repositories/sqlite_person_repository.dart';
import 'package:workpulse/data/repositories/sqlite_project_repository.dart';
import 'package:workpulse/data/repositories/sqlite_session_repository.dart';
import 'package:workpulse/data/repositories/sqlite_tag_repository.dart';
import 'package:workpulse/data/repositories/sqlite_work_item_repository.dart';
import 'package:workpulse/data/repositories/sqlite_workspace_repository.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/domain/services/work_item_merge_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WorkItemMergeService Domain Unit Tests', () {
    late DatabaseService dbService;
    late SqliteWorkspaceRepository workspaceRepo;
    late SqliteProjectRepository projectRepo;
    late SqliteCategoryRepository categoryRepo;
    late SqliteTagRepository tagRepo;
    late SqlitePersonRepository personRepo;
    late SqliteWorkItemRepository workItemRepo;
    late SqliteSessionRepository sessionRepo;
    late SqliteAttributeRepository attributeRepo;
    late WorkItemMergeService mergeService;

    const wsId = MigrationV1.defaultWorkspaceId;
    late Project defaultProject;
    late Category defaultCategory;

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

      mergeService = WorkItemMergeService(
        workItemRepository: workItemRepo,
        sessionRepository: sessionRepo,
        attributeRepository: attributeRepo,
      );

      final now = DateTime.utc(2026, 8, 23, 10, 0);

      defaultProject = await projectRepo.create(
        Project(
          id: 'proj-1',
          workspaceId: wsId,
          name: 'Merge Test Project',
          createdAt: now,
          updatedAt: now,
        ),
      );

      defaultCategory = await categoryRepo.create(
        Category(
          id: 'cat-1',
          workspaceId: wsId,
          name: 'Engineering',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(() async {
      await dbService.close();
    });

    test('reassigns all sessions from source to target and deletes source',
        () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      final source = await workItemRepo.create(
        WorkItem(
          id: 'wi-source',
          workspaceId: wsId,
          projectId: defaultProject.id,
          categoryId: defaultCategory.id,
          name: 'Source Task (Duplicate)',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final target = await workItemRepo.create(
        WorkItem(
          id: 'wi-target',
          workspaceId: wsId,
          projectId: defaultProject.id,
          categoryId: defaultCategory.id,
          name: 'Target Task (Preserved)',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Create 2 sessions on source and 1 on target
      await sessionRepo.create(Session(
        id: 's-1',
        workItemId: source.id,
        startTime: now,
        endTime: now.add(const Duration(minutes: 30)),
        createdAt: now,
      ));
      await sessionRepo.create(Session(
        id: 's-2',
        workItemId: source.id,
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 2)),
        createdAt: now,
      ));
      await sessionRepo.create(Session(
        id: 's-3',
        workItemId: target.id,
        startTime: now.add(const Duration(hours: 3)),
        endTime: now.add(const Duration(hours: 4)),
        createdAt: now,
      ));

      expect(await sessionRepo.countByWorkItemId(source.id), equals(2));
      expect(await sessionRepo.countByWorkItemId(target.id), equals(1));

      final result = await mergeService.mergeWorkItems(
        const WorkItemMergeRequest(
          sourceWorkItemId: 'wi-source',
          targetWorkItemId: 'wi-target',
          deleteSource: true,
        ),
      );

      expect(result.sessionsMovedCount, equals(2));
      expect(result.sourceDeleted, isTrue);

      // Target now has all 3 sessions
      expect(await sessionRepo.countByWorkItemId(target.id), equals(3));
      final allSessions = await sessionRepo.getByWorkItemId(target.id);
      expect(allSessions.map((s) => s.id), containsAll(['s-1', 's-2', 's-3']));

      // Source work item is deleted
      expect(await workItemRepo.getById(source.id), isNull);
    });

    test('merges tags, people, notes, and updates lastWorkedAt', () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      await tagRepo.create(Tag(
        id: 't-shared',
        workspaceId: wsId,
        name: 'Shared Tag',
        createdAt: now,
      ));
      await tagRepo.create(Tag(
        id: 't-src',
        workspaceId: wsId,
        name: 'Source Tag',
        createdAt: now,
      ));
      await tagRepo.create(Tag(
        id: 't-tgt',
        workspaceId: wsId,
        name: 'Target Tag',
        createdAt: now,
      ));

      await personRepo.create(Person(
        id: 'p-shared',
        workspaceId: wsId,
        name: 'Shared Person',
        createdAt: now,
      ));
      await personRepo.create(Person(
        id: 'p-src',
        workspaceId: wsId,
        name: 'Source Person',
        createdAt: now,
      ));

      await workItemRepo.create(
        WorkItem(
          id: 'wi-source-meta',
          workspaceId: wsId,
          projectId: defaultProject.id,
          categoryId: defaultCategory.id,
          name: 'Source Task',
          tagIds: const ['t-shared', 't-src'],
          peopleIds: const ['p-shared', 'p-src'],
          notes: 'Source notes content',
          lastWorkedAt: DateTime.utc(2026, 8, 23, 15, 30),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await workItemRepo.create(
        WorkItem(
          id: 'wi-target-meta',
          workspaceId: wsId,
          projectId: defaultProject.id,
          categoryId: defaultCategory.id,
          name: 'Target Task',
          tagIds: const ['t-shared', 't-tgt'],
          peopleIds: const ['p-shared'],
          notes: 'Initial target notes',
          lastWorkedAt: DateTime.utc(2026, 8, 23, 12, 0),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final result = await mergeService.mergeWorkItems(
        const WorkItemMergeRequest(
          sourceWorkItemId: 'wi-source-meta',
          targetWorkItemId: 'wi-target-meta',
          combineNotes: true,
          combineTags: true,
          combinePeople: true,
          deleteSource: true,
        ),
      );

      // Verify merged tags: union of shared, tgt, src
      expect(result.targetWorkItem.tagIds,
          containsAll(['t-shared', 't-tgt', 't-src']));
      expect(result.targetWorkItem.tagIds.length, equals(3));

      // Verify merged people: union of shared, src
      expect(
          result.targetWorkItem.peopleIds, containsAll(['p-shared', 'p-src']));
      expect(result.targetWorkItem.peopleIds.length, equals(2));

      // Verify combined notes
      expect(
        result.targetWorkItem.notes,
        contains('Initial target notes'),
      );
      expect(
        result.targetWorkItem.notes,
        contains('Merged from "Source Task"'),
      );
      expect(
        result.targetWorkItem.notes,
        contains('Source notes content'),
      );

      // Verify lastWorkedAt updated to the later timestamp (15:30)
      expect(
        result.targetWorkItem.lastWorkedAt,
        equals(DateTime.utc(2026, 8, 23, 15, 30)),
      );
    });

    test('merges custom attribute values from source to target without overwriting',
        () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      final attr1 = AttributeDefinition(
        id: 'attr-1',
        workspaceId: wsId,
        key: 'issue_key',
        name: 'Issue Key',
        type: AttributeType.text,
        scope: AttributeScope.task,
        createdAt: now,
        updatedAt: now,
      );
      final attr2 = AttributeDefinition(
        id: 'attr-2',
        workspaceId: wsId,
        key: 'priority_num',
        name: 'Priority Num',
        type: AttributeType.number,
        scope: AttributeScope.task,
        createdAt: now,
        updatedAt: now,
      );
      await attributeRepo.createDefinition(attr1);
      await attributeRepo.createDefinition(attr2);

      final source = await workItemRepo.create(
        WorkItem(
          id: 'wi-src-attr',
          workspaceId: wsId,
          name: 'Src',
          projectId: defaultProject.id,
          categoryId: defaultCategory.id,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final target = await workItemRepo.create(
        WorkItem(
          id: 'wi-tgt-attr',
          workspaceId: wsId,
          name: 'Tgt',
          projectId: defaultProject.id,
          categoryId: defaultCategory.id,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Source has attr1 and attr2
      await attributeRepo.setWorkItemValue(WorkItemAttributeValue(
        id: 'val-src-1',
        workItemId: source.id,
        attributeDefinitionId: 'attr-1',
        textValue: 'SRC-101',
        createdAt: now,
        updatedAt: now,
      ));
      await attributeRepo.setWorkItemValue(WorkItemAttributeValue(
        id: 'val-src-2',
        workItemId: source.id,
        attributeDefinitionId: 'attr-2',
        numberValue: 99,
        createdAt: now,
        updatedAt: now,
      ));

      // Target already has its own attr1
      await attributeRepo.setWorkItemValue(WorkItemAttributeValue(
        id: 'val-tgt-1',
        workItemId: target.id,
        attributeDefinitionId: 'attr-1',
        textValue: 'TGT-999',
        createdAt: now,
        updatedAt: now,
      ));

      await mergeService.mergeWorkItems(
        const WorkItemMergeRequest(
          sourceWorkItemId: 'wi-src-attr',
          targetWorkItemId: 'wi-tgt-attr',
          combineAttributes: true,
          deleteSource: true,
        ),
      );

      final tgtValues = await attributeRepo.getWorkItemValues(target.id);
      expect(tgtValues.length, equals(2));

      // Target's existing attr1 was preserved
      final val1 =
          tgtValues.firstWhere((v) => v.attributeDefinitionId == 'attr-1');
      expect(val1.textValue, equals('TGT-999'));

      // Source's attr2 was copied over
      final val2 =
          tgtValues.firstWhere((v) => v.attributeDefinitionId == 'attr-2');
      expect(val2.numberValue, equals(99));
    });

    test('archives source instead of deleting when deleteSource is false',
        () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      final source = await workItemRepo.create(
        WorkItem(
          id: 'wi-archive-src',
          workspaceId: wsId,
          projectId: defaultProject.id,
          categoryId: defaultCategory.id,
          name: 'Keep Archived Task',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await workItemRepo.create(
        WorkItem(
          id: 'wi-archive-tgt',
          workspaceId: wsId,
          projectId: defaultProject.id,
          categoryId: defaultCategory.id,
          name: 'Target Task',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final result = await mergeService.mergeWorkItems(
        const WorkItemMergeRequest(
          sourceWorkItemId: 'wi-archive-src',
          targetWorkItemId: 'wi-archive-tgt',
          deleteSource: false,
        ),
      );

      expect(result.sourceDeleted, isFalse);

      final sourceAfterMerge = await workItemRepo.getById(source.id);
      expect(sourceAfterMerge, isNotNull);
      expect(sourceAfterMerge!.isArchived, isTrue);
    });

    test('validates self-merge, missing items, and workspace mismatch',
        () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      final itemA = await workItemRepo.create(
        WorkItem(
          id: 'wi-val-a',
          workspaceId: wsId,
          projectId: defaultProject.id,
          categoryId: defaultCategory.id,
          name: 'A',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Cannot merge into itself
      expect(
        () => mergeService.mergeWorkItems(
          const WorkItemMergeRequest(
            sourceWorkItemId: 'wi-val-a',
            targetWorkItemId: 'wi-val-a',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );

      // Nonexistent source
      expect(
        () => mergeService.mergeWorkItems(
          const WorkItemMergeRequest(
            sourceWorkItemId: 'wi-nonexistent',
            targetWorkItemId: 'wi-val-a',
          ),
        ),
        throwsA(isA<NotFoundException>()),
      );

      // Nonexistent target
      expect(
        () => mergeService.mergeWorkItems(
          const WorkItemMergeRequest(
            sourceWorkItemId: 'wi-val-a',
            targetWorkItemId: 'wi-nonexistent',
          ),
        ),
        throwsA(isA<NotFoundException>()),
      );

      // Different workspaces
      final customWs = await workspaceRepo.create(
        Workspace(
          id: 'ws-different',
          name: 'Other Workspace',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final customCategory = await categoryRepo.create(
        Category(
          id: 'cat-custom',
          workspaceId: customWs.id,
          name: 'Custom Cat',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final itemOtherWs = await workItemRepo.create(
        WorkItem(
          id: 'wi-other-ws',
          workspaceId: customWs.id,
          projectId: defaultProject.id,
          categoryId: customCategory.id,
          name: 'Other WS Item',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(
        () => mergeService.mergeWorkItems(
          WorkItemMergeRequest(
            sourceWorkItemId: itemOtherWs.id,
            targetWorkItemId: itemA.id,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
