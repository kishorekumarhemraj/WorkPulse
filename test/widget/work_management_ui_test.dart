import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/constants/app_constants.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/categories/views/categories_view.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/people/views/people_view.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/projects/views/project_form_dialog.dart';
import 'package:workpulse/features/projects/views/projects_view.dart';
import 'package:workpulse/features/shell/views/main_shell_view.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tags/views/tags_view.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/tasks/views/task_form_dialog.dart';
import 'package:workpulse/features/tasks/views/tasks_view.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

void main() {
  group('Work Management UI Widget Tests', () {
    final now = DateTime.now().toUtc();
    final testWorkspace = Workspace(
      id: 'ws-1',
      name: 'Default',
      createdAt: now,
      updatedAt: now,
    );
    final testProject = Project(
      id: 'proj-1',
      workspaceId: 'ws-1',
      name: 'Alpha Project',
      description: 'Alpha description',
      colorHex: '#0A84FF',
      createdAt: now,
      updatedAt: now,
    );
    final testCategory = Category(
      id: 'cat-1',
      workspaceId: 'ws-1',
      name: 'Engineering',
      description: 'Dev work',
      iconName: 'code',
      createdAt: now,
      updatedAt: now,
    );
    final testTag = Tag(
      id: 'tag-1',
      workspaceId: 'ws-1',
      name: 'Urgent',
      colorHex: '#FF453A',
      createdAt: now,
    );
    final testPerson = Person(
      id: 'person-1',
      workspaceId: 'ws-1',
      name: 'Alice Smith',
      email: 'alice@example.com',
      createdAt: now,
    );
    final testWorkItem = WorkItem(
      id: 'item-1',
      workspaceId: 'ws-1',
      name: 'Build Authentication',
      projectId: 'proj-1',
      categoryId: 'cat-1',
      tagIds: ['tag-1'],
      peopleIds: ['person-1'],
      notes: 'Initial notes',
      createdAt: now,
      updatedAt: now,
    );

    Widget createTestApp({Widget? child}) {
      return ProviderScope(
        overrides: [
          currentWorkspaceProvider.overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
          projectsProvider.overrideWith(() => _FakeProjectsNotifier([testProject])),
          categoriesProvider.overrideWith(() => _FakeCategoriesNotifier([testCategory])),
          tagsProvider.overrideWith(() => _FakeTagsNotifier([testTag])),
          peopleProvider.overrideWith(() => _FakePeopleNotifier([testPerson])),
          workItemsProvider.overrideWith(() => _FakeWorkItemsNotifier([testWorkItem])),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: child != null ? Scaffold(body: child) : const MainShellView(),
        ),
      );
    }

    testWidgets('MainShellView renders sidebar and switches views', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Brand and Workspace
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);

      // Work items should be visible
      expect(find.byType(TasksView), findsOneWidget);
      expect(find.text('Build Authentication'), findsOneWidget);

      // Switch to Projects
      await tester.tap(find.byIcon(Icons.folder_outlined).first);
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsView), findsOneWidget);
      expect(find.text('Alpha Project'), findsOneWidget);

      // Switch to Categories
      await tester.tap(find.byIcon(Icons.category_outlined).first);
      await tester.pumpAndSettle();
      expect(find.byType(CategoriesView), findsOneWidget);
      expect(find.text('Engineering'), findsOneWidget);

      // Switch to Tags
      await tester.tap(find.byIcon(Icons.label_outline).first);
      await tester.pumpAndSettle();
      expect(find.byType(TagsView), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);

      // Switch to People
      await tester.tap(find.byIcon(Icons.people_outline).first);
      await tester.pumpAndSettle();
      expect(find.byType(PeopleView), findsOneWidget);
      expect(find.text('Alice Smith'), findsOneWidget);
    });

    testWidgets('ProjectFormDialog validates and saves', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ProjectFormDialog.show(context),
              child: const Text('Open Project Dialog'),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Project Dialog'));
      await tester.pump();

      expect(find.text('New Project'), findsOneWidget);

      // Trigger validation
      await tester.tap(find.text('Create Project'));
      await tester.pump();
      expect(find.text('Project name is required'), findsOneWidget);

      // Fill name and save
      await tester.enterText(find.byType(TextFormField).first, 'Beta Project');
      await tester.tap(find.text('Create Project'));
      await tester.pump();

      expect(find.text('New Project'), findsNothing);
    });

    testWidgets('TaskFormDialog validates required name and creates task', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => TaskFormDialog.show(context),
              child: const Text('Open Task Dialog'),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Task Dialog'));
      await tester.pump();

      expect(find.text('New Work Item'), findsOneWidget);

      // Trigger validation with empty name
      await tester.tap(find.text('Create Task'));
      await tester.pump();
      expect(find.text('Task name is required'), findsOneWidget);

      // Enter name and save
      await tester.enterText(find.byType(TextFormField).first, 'Implement feature XYZ');
      await tester.tap(find.text('Create Task'));
      await tester.pump();

      expect(find.text('New Work Item'), findsNothing);
    });
  });
}

class _FakeWorkspaceNotifier extends CurrentWorkspaceNotifier {
  final Workspace _ws;
  _FakeWorkspaceNotifier(this._ws);
  @override
  Future<Workspace> build() async => _ws;
}

class _FakeProjectsNotifier extends ProjectsNotifier {
  final List<Project> _list;
  _FakeProjectsNotifier(this._list);
  @override
  Future<List<Project>> build() async => _list;
  @override
  Future<Project> createProject({required String name, String? description, String? colorHex}) async {
    final p = Project(
      id: 'new-p',
      workspaceId: 'ws-1',
      name: name,
      description: description,
      colorHex: colorHex,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _list.add(p);
    state = AsyncData(_list);
    return p;
  }
}

class _FakeCategoriesNotifier extends CategoriesNotifier {
  final List<Category> _list;
  _FakeCategoriesNotifier(this._list);
  @override
  Future<List<Category>> build() async => _list;
}

class _FakeTagsNotifier extends TagsNotifier {
  final List<Tag> _list;
  _FakeTagsNotifier(this._list);
  @override
  Future<List<Tag>> build() async => _list;
}

class _FakePeopleNotifier extends PeopleNotifier {
  final List<Person> _list;
  _FakePeopleNotifier(this._list);
  @override
  Future<List<Person>> build() async => _list;
}

class _FakeWorkItemsNotifier extends WorkItemsNotifier {
  final List<WorkItem> _list;
  _FakeWorkItemsNotifier(this._list);
  @override
  Future<List<WorkItem>> build() async => _list;
  @override
  Future<WorkItem> createWorkItem({
    required String name,
    required String projectId,
    required String categoryId,
    String? notes,
    List<String> tagIds = const [],
    List<String> peopleIds = const [],
  }) async {
    final item = WorkItem(
      id: 'new-item',
      workspaceId: 'ws-1',
      name: name,
      projectId: projectId,
      categoryId: categoryId,
      notes: notes,
      tagIds: tagIds,
      peopleIds: peopleIds,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _list.add(item);
    state = AsyncData(_list);
    return item;
  }
}
