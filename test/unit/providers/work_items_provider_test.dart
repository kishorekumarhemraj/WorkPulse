import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WorkItemsProvider & WorkItemFilter Tests', () {
    late DatabaseService dbService;
    late ProviderContainer container;
    const uuid = Uuid();
    final now = DateTime.now().toUtc();

    late Workspace testWorkspace;
    late Project testProjectA;
    late Project testProjectB;
    late Category testCategoryA;
    late Tag testTag;
    late Person testPerson;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      testWorkspace = Workspace(
          id: uuid.v4(), name: 'Test WS', createdAt: now, updatedAt: now);
      await dbService.database.insert('workspaces', {
        'id': testWorkspace.id,
        'name': testWorkspace.name,
        'created_at': testWorkspace.createdAt.toIso8601String(),
        'updated_at': testWorkspace.updatedAt.toIso8601String(),
      });

      testProjectA = Project(
          id: uuid.v4(),
          workspaceId: testWorkspace.id,
          name: 'Project A',
          createdAt: now,
          updatedAt: now);
      testProjectB = Project(
          id: uuid.v4(),
          workspaceId: testWorkspace.id,
          name: 'Project B',
          createdAt: now,
          updatedAt: now);
      await dbService.database.insert('projects', {
        'id': testProjectA.id,
        'workspace_id': testProjectA.workspaceId,
        'name': testProjectA.name,
        'created_at': testProjectA.createdAt.toIso8601String(),
        'updated_at': testProjectA.updatedAt.toIso8601String(),
      });
      await dbService.database.insert('projects', {
        'id': testProjectB.id,
        'workspace_id': testProjectB.workspaceId,
        'name': testProjectB.name,
        'created_at': testProjectB.createdAt.toIso8601String(),
        'updated_at': testProjectB.updatedAt.toIso8601String(),
      });

      testCategoryA = Category(
          id: uuid.v4(),
          workspaceId: testWorkspace.id,
          name: 'Dev',
          createdAt: now,
          updatedAt: now);
      await dbService.database.insert('categories', {
        'id': testCategoryA.id,
        'workspace_id': testCategoryA.workspaceId,
        'name': testCategoryA.name,
        'created_at': testCategoryA.createdAt.toIso8601String(),
        'updated_at': testCategoryA.updatedAt.toIso8601String(),
      });

      testTag = Tag(
          id: uuid.v4(),
          workspaceId: testWorkspace.id,
          name: 'Urgent',
          createdAt: now);
      await dbService.database.insert('tags', {
        'id': testTag.id,
        'workspace_id': testTag.workspaceId,
        'name': testTag.name,
        'created_at': testTag.createdAt.toIso8601String(),
      });

      testPerson = Person(
          id: uuid.v4(),
          workspaceId: testWorkspace.id,
          name: 'Alice',
          createdAt: now);
      await dbService.database.insert('people', {
        'id': testPerson.id,
        'workspace_id': testPerson.workspaceId,
        'name': testPerson.name,
        'created_at': testPerson.createdAt.toIso8601String(),
      });

      container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWithValue(dbService),
          currentWorkspaceProvider
              .overrideWith(() => _MockWorkspaceNotifier(testWorkspace)),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await dbService.close();
    });

    test('WorkItemFilter updates state correctly', () {
      final filterNotifier = container.read(workItemFilterProvider.notifier);

      expect(container.read(workItemFilterProvider).hasActiveFilters, isFalse);

      filterNotifier.setSearchQuery('test');
      expect(container.read(workItemFilterProvider).searchQuery, 'test');
      expect(container.read(workItemFilterProvider).hasActiveFilters, isTrue);

      filterNotifier.setProject(testProjectA.id);
      expect(container.read(workItemFilterProvider).projectId, testProjectA.id);

      filterNotifier.setCategory(testCategoryA.id);
      expect(
          container.read(workItemFilterProvider).categoryId, testCategoryA.id);

      filterNotifier.setTag(testTag.id);
      expect(container.read(workItemFilterProvider).tagId, testTag.id);

      filterNotifier.setPerson(testPerson.id);
      expect(container.read(workItemFilterProvider).personId, testPerson.id);

      filterNotifier.toggleIncludeArchived();
      expect(container.read(workItemFilterProvider).includeArchived, isTrue);

      filterNotifier.reset();
      expect(container.read(workItemFilterProvider).hasActiveFilters, isFalse);
      expect(container.read(workItemFilterProvider).searchQuery, '');
    });

    test('WorkItemsNotifier CRUD and filtering operations', () async {
      final notifier = container.read(workItemsProvider.notifier);

      // 1. Initial list should be empty
      var items = await container.read(workItemsProvider.future);
      expect(items, isEmpty);

      // 2. Create items
      final item1 = await notifier.createWorkItem(
        name: 'Task Alpha',
        projectId: testProjectA.id,
        categoryId: testCategoryA.id,
        notes: 'Alpha notes',
        tagIds: [testTag.id],
        peopleIds: [testPerson.id],
      );
      expect(item1.name, 'Task Alpha');

      final item2 = await notifier.createWorkItem(
        name: 'Task Beta',
        projectId: testProjectB.id,
        categoryId: testCategoryA.id,
        notes: 'Beta notes',
      );

      items = await container.read(workItemsProvider.future);
      expect(items.length, 2);

      // 3. Filter by project
      container
          .read(workItemFilterProvider.notifier)
          .setProject(testProjectA.id);
      items = await container.read(workItemsProvider.future);
      expect(items.length, 1);
      expect(items.first.id, item1.id);

      // 4. Search query
      container.read(workItemFilterProvider.notifier).reset();
      container.read(workItemFilterProvider.notifier).setSearchQuery('Beta');
      items = await container.read(workItemsProvider.future);
      expect(items.length, 1);
      expect(items.first.id, item2.id);

      // 5. Update item
      container.read(workItemFilterProvider.notifier).reset();
      final updated = await notifier
          .updateWorkItem(item1.copyWith(name: 'Task Alpha Updated'));
      expect(updated.name, 'Task Alpha Updated');

      // 6. Archive item
      await notifier.archiveWorkItem(item1.id);
      items = await container.read(workItemsProvider.future);
      expect(items.length, 1);
      expect(items.first.id, item2.id);

      // Include archived
      container.read(workItemFilterProvider.notifier).toggleIncludeArchived();
      items = await container.read(workItemsProvider.future);
      expect(items.length, 2);

      // 7. Delete item
      await notifier.deleteWorkItem(item2.id);
      items = await container.read(workItemsProvider.future);
      expect(items.length, 1);
      expect(items.first.id, item1.id);
    });

    test('a task round-trips its financial classification through SQLite',
        () async {
      final notifier = container.read(workItemsProvider.notifier);

      final capex = await notifier.createWorkItem(
        name: 'Build the thing',
        projectId: testProjectA.id,
        categoryId: testCategoryA.id,
        classification: FinancialClassification.capex,
      );
      expect(capex.financialClassification, FinancialClassification.capex);

      // Unstated means unclassified. Defaulting to OpEx would invent a
      // finance decision nobody made.
      final defaulted = await notifier.createWorkItem(
        name: 'Unclassified work',
        projectId: testProjectA.id,
        categoryId: testCategoryA.id,
      );
      expect(defaulted.financialClassification, FinancialClassification.none);

      container.read(workItemFilterProvider.notifier).reset();
      final reloaded = await container.read(workItemsProvider.future);
      expect(
        reloaded.firstWhere((w) => w.id == capex.id).financialClassification,
        FinancialClassification.capex,
      );

      final reclassified = await notifier.updateWorkItem(
        capex.copyWith(
          financialClassification: FinancialClassification.opex,
        ),
      );
      expect(
        reclassified.financialClassification,
        FinancialClassification.opex,
      );
    });
  });
}

class _MockWorkspaceNotifier extends CurrentWorkspaceNotifier {
  final Workspace _workspace;
  _MockWorkspaceNotifier(this._workspace);

  @override
  Future<Workspace> build() async => _workspace;
}
