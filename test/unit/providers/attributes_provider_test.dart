import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/data/repositories/sqlite_attribute_repository.dart';
import 'package:workpulse/data/repositories/sqlite_category_repository.dart';
import 'package:workpulse/data/repositories/sqlite_project_repository.dart';
import 'package:workpulse/data/repositories/sqlite_work_item_repository.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Configurable Attributes Provider Unit Tests', () {
    late DatabaseService dbService;
    late SqliteAttributeRepository attrRepo;
    late SqliteProjectRepository projectRepo;
    late SqliteCategoryRepository categoryRepo;
    late SqliteWorkItemRepository workItemRepo;

    const wsId = MigrationV1.defaultWorkspaceId;
    late Project defaultProject;
    late Category defaultCategory;
    late WorkItem defaultWorkItem;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      attrRepo = SqliteAttributeRepository(dbService);
      projectRepo = SqliteProjectRepository(dbService);
      categoryRepo = SqliteCategoryRepository(dbService);
      workItemRepo = SqliteWorkItemRepository(dbService);

      final now = DateTime.now().toUtc();

      defaultProject = await projectRepo.create(
        Project(id: 'proj-1', workspaceId: wsId, name: 'Core', createdAt: now, updatedAt: now),
      );

      defaultCategory = await categoryRepo.create(
        Category(id: 'cat-1', workspaceId: wsId, name: 'Dev', createdAt: now, updatedAt: now),
      );

      defaultWorkItem = await workItemRepo.create(
        WorkItem(
          id: 'item-1',
          workspaceId: wsId,
          projectId: defaultProject.id,
          categoryId: defaultCategory.id,
          name: 'Task 1',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(() async {
      await dbService.close();
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          attributeRepositoryProvider.overrideWithValue(attrRepo),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('AttributeDefinitionsNotifier CRUD and toggle lifecycle', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(attributeDefinitionsProvider.future);

      final notifier = container.read(attributeDefinitionsProvider.notifier);

      // Create definition
      final created = await notifier.createDefinition(
        key: 'jira_key',
        name: 'Jira Key',
        type: AttributeType.text,
        scope: AttributeScope.task,
        required: true,
      );

      expect(created.id, isNotEmpty);
      expect(created.key, 'jira_key');
      expect(created.name, 'Jira Key');
      expect(created.type, AttributeType.text);
      expect(created.scope, AttributeScope.task);
      expect(created.required, isTrue);

      var list = await container.read(attributeDefinitionsProvider.future);
      expect(list.length, 1);

      // Update definition
      final updated = await notifier.updateDefinition(
        created.copyWith(name: 'Jira Issue Key', showInQuickCapture: false),
      );
      expect(updated.name, 'Jira Issue Key');
      expect(updated.showInQuickCapture, isFalse);

      // Toggle enabled
      await notifier.toggleEnabled(created.id, false);
      list = await container.read(attributeDefinitionsProvider.future);
      expect(list.first.enabled, isFalse);

      // Soft-archive definition
      await notifier.archiveDefinition(created.id);
      list = await container.read(attributeDefinitionsProvider.future);
      expect(list.isEmpty, isTrue); // Excluded from active list
    });

    test('AttributeOptionsController creates, updates, and archives select options', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);

      final defNotifier = container.read(attributeDefinitionsProvider.notifier);
      final selectDef = await defNotifier.createDefinition(
        key: 'priority',
        name: 'Priority',
        type: AttributeType.singleSelect,
      );

      final optController = container.read(attributeOptionsControllerProvider);

      // Create options
      final opt1 = await optController.createOption(
        definitionId: selectDef.id,
        value: 'high',
        label: 'High',
        colorHex: '#FF3B30',
        isDefault: true,
      );
      final opt2 = await optController.createOption(
        definitionId: selectDef.id,
        value: 'low',
        label: 'Low',
        colorHex: '#34C759',
      );

      var options = await container.read(attributeOptionsFamilyProvider(selectDef.id).future);
      expect(options.length, 2);
      expect(options.first.label, 'High');
      expect(options.first.isDefault, isTrue);

      // Update option
      final updatedOpt = await optController.updateOption(opt1.copyWith(label: 'Critical / High'));
      expect(updatedOpt.label, 'Critical / High');

      // Archive option
      await optController.archiveOption(selectDef.id, opt2.id);
      options = await container.read(attributeOptionsFamilyProvider(selectDef.id).future);
      expect(options.length, 1);
      expect(options.first.id, opt1.id);
    });

    test('WorkItemAttributeValuesController sets and persists typed values', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);

      final defNotifier = container.read(attributeDefinitionsProvider.notifier);
      final textDef = await defNotifier.createDefinition(key: 'client_code', name: 'Client Code', type: AttributeType.text);
      final numDef = await defNotifier.createDefinition(key: 'story_points', name: 'Story Points', type: AttributeType.number);
      final boolDef = await defNotifier.createDefinition(key: 'is_billable', name: 'Billable', type: AttributeType.boolean);

      final valuesController = container.read(workItemAttributeValuesControllerProvider);

      final now = DateTime.now().toUtc();
      await valuesController.saveValues(defaultWorkItem.id, [
        WorkItemAttributeValue(
          id: 'val-1',
          workItemId: defaultWorkItem.id,
          attributeDefinitionId: textDef.id,
          textValue: 'ACME_CORP',
          createdAt: now,
          updatedAt: now,
        ),
        WorkItemAttributeValue(
          id: 'val-2',
          workItemId: defaultWorkItem.id,
          attributeDefinitionId: numDef.id,
          numberValue: 8.0,
          createdAt: now,
          updatedAt: now,
        ),
        WorkItemAttributeValue(
          id: 'val-3',
          workItemId: defaultWorkItem.id,
          attributeDefinitionId: boolDef.id,
          booleanValue: true,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      final values = await container.read(workItemAttributeValuesFamilyProvider(defaultWorkItem.id).future);
      expect(values.length, 3);

      final textVal = values.firstWhere((v) => v.attributeDefinitionId == textDef.id);
      expect(textVal.textValue, 'ACME_CORP');

      final numVal = values.firstWhere((v) => v.attributeDefinitionId == numDef.id);
      expect(numVal.numberValue, 8.0);

      final boolVal = values.firstWhere((v) => v.attributeDefinitionId == boolDef.id);
      expect(boolVal.booleanValue, isTrue);
    });
  });
}
