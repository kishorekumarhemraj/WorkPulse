import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/project_timesheet_code.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Projects, Categories, Tags, People Notifier Tests', () {
    late DatabaseService dbService;
    late ProviderContainer container;
    const uuid = Uuid();
    final now = DateTime.now().toUtc();
    late Workspace testWorkspace;

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

    test('ProjectsNotifier CRUD operations', () async {
      final notifier = container.read(projectsProvider.notifier);

      var projects = await container.read(projectsProvider.future);
      expect(projects, isEmpty);

      final p1 = await notifier.createProject(
          name: 'Project 1', description: 'Desc 1', colorHex: '#0A84FF');
      expect(p1.name, 'Project 1');

      final p2 = await notifier.createProject(name: 'Project 2');
      projects = await container.read(projectsProvider.future);
      expect(projects.length, 2);

      final updated =
          await notifier.updateProject(p1.copyWith(name: 'Project 1 Edited'));
      expect(updated.name, 'Project 1 Edited');

      await notifier.archiveProject(p1.id);
      projects = await container.read(projectsProvider.future);
      expect(projects.length, 1);
      expect(projects.first.id, p2.id);

      await notifier.unarchiveProject(p1.id);
      projects = await container.read(projectsProvider.future);
      expect(projects.length, 2);

      await notifier.deleteProject(p2.id);
      projects = await container.read(projectsProvider.future);
      expect(projects.length, 1);
    });

    test('a project round-trips its timesheet code through SQLite', () async {
      final notifier = container.read(projectsProvider.notifier);

      final coded = await notifier.createProject(
        name: 'Apollo',
        timesheetCode: 'PRJ-1042',
      );
      expect(coded.timesheetCode, 'PRJ-1042');
      expect(coded.hasTimesheetCode, isTrue);

      // Whitespace-only is stored as absent, not as a blank code that would
      // print as an empty cell on the Time Sheet.
      final blank =
          await notifier.createProject(name: 'Zephyr', timesheetCode: '   ');
      expect(blank.timesheetCode, isNull);
      expect(blank.hasTimesheetCode, isFalse);

      final reloaded = await container.read(projectsProvider.future);
      expect(
        reloaded.firstWhere((p) => p.id == coded.id).timesheetCode,
        'PRJ-1042',
      );

      final recoded =
          await notifier.updateProject(coded.copyWith(timesheetCode: 'CC-99'));
      expect(recoded.timesheetCode, 'CC-99');
      final afterUpdate = await container.read(projectsProvider.future);
      expect(
        afterUpdate.firstWhere((p) => p.id == coded.id).timesheetCode,
        'CC-99',
      );
    });

    test('ProjectsNotifier manages discriminator and option timesheet codes', () async {
      final notifier = container.read(projectsProvider.notifier);

      // Create definition and options in DB for foreign key constraints
      await dbService.database.insert('attribute_definitions', {
        'id': 'def-rel',
        'workspace_id': testWorkspace.id,
        'key': 'release',
        'name': 'Release',
        'type': 'single_select',
        'scope': 'TASK',
        'enabled': 1,
        'reportable': 1,
        'display_order': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await dbService.database.insert('attribute_options', {
        'id': 'opt-r1',
        'attribute_definition_id': 'def-rel',
        'label': 'R1.0',
        'value': 'r1.0',
        'display_order': 0,
        'created_at': now.toIso8601String(),
      });

      final proj = await notifier.createProject(
        name: 'Varying Project',
        timesheetCode: 'DEFAULT-CODE',
        codeAttributeDefinitionId: 'def-rel',
      );
      expect(proj.codeAttributeDefinitionId, 'def-rel');

      final projectTimesheetCode = ProjectTimesheetCode(
        id: uuid.v4(),
        projectId: proj.id,
        attributeOptionId: 'opt-r1',
        code: 'VARY-R1',
        createdAt: now,
        updatedAt: now,
      );

      await notifier.updateProject(proj, timesheetCodes: [projectTimesheetCode]);

      final loadedCodes = await notifier.getTimesheetCodes(proj.id);
      expect(loadedCodes, hasLength(1));
      expect(loadedCodes.first.code, 'VARY-R1');
      expect(loadedCodes.first.attributeOptionId, 'opt-r1');
    });

    test('CategoriesNotifier CRUD operations', () async {
      final notifier = container.read(categoriesProvider.notifier);

      var categories = await container.read(categoriesProvider.future);
      expect(categories, isEmpty);

      final c1 = await notifier.createCategory(
          name: 'Engineering', description: 'Dev work', iconName: 'code');
      expect(c1.name, 'Engineering');

      final c2 = await notifier.createCategory(name: 'Design');
      categories = await container.read(categoriesProvider.future);
      expect(categories.length, 2);

      final updated =
          await notifier.updateCategory(c1.copyWith(name: 'Engineering & QA'));
      expect(updated.name, 'Engineering & QA');

      await notifier.archiveCategory(c1.id);
      categories = await container.read(categoriesProvider.future);
      expect(categories.length, 1);

      await notifier.deleteCategory(c2.id);
      categories = await container.read(categoriesProvider.future);
      expect(categories, isEmpty);
    });

    test('TagsNotifier CRUD operations', () async {
      final notifier = container.read(tagsProvider.notifier);

      var tags = await container.read(tagsProvider.future);
      expect(tags, isEmpty);

      final t1 =
          await notifier.createTag(name: 'Frontend', colorHex: '#30D158');
      expect(t1.name, 'Frontend');

      final t2 = await notifier.createTag(name: 'Backend');
      tags = await container.read(tagsProvider.future);
      expect(tags.length, 2);

      final updated =
          await notifier.updateTag(t1.copyWith(name: 'UI / Frontend'));
      expect(updated.name, 'UI / Frontend');

      await notifier.deleteTag(t2.id);
      tags = await container.read(tagsProvider.future);
      expect(tags.length, 1);
      expect(tags.first.name, 'UI / Frontend');
    });

    test('PeopleNotifier CRUD operations', () async {
      final notifier = container.read(peopleProvider.notifier);

      var people = await container.read(peopleProvider.future);
      expect(people, isEmpty);

      final p1 = await notifier.createPerson(
          name: 'John Doe', email: 'john@example.com');
      expect(p1.name, 'John Doe');

      final p2 = await notifier.createPerson(name: 'Jane Smith');
      people = await container.read(peopleProvider.future);
      expect(people.length, 2);

      final updated =
          await notifier.updatePerson(p1.copyWith(name: 'Johnathan Doe'));
      expect(updated.name, 'Johnathan Doe');

      await notifier.deletePerson(p2.id);
      people = await container.read(peopleProvider.future);
      expect(people.length, 1);
      expect(people.first.name, 'Johnathan Doe');
    });
  });
}

class _MockWorkspaceNotifier extends CurrentWorkspaceNotifier {
  final Workspace _workspace;
  _MockWorkspaceNotifier(this._workspace);

  @override
  Future<Workspace> build() async => _workspace;
}
