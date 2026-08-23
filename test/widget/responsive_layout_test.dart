import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/attributes/views/attribute_definitions_view.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/categories/views/categories_view.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/people/views/people_view.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/projects/views/projects_view.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tags/views/tags_view.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/tasks/views/tasks_view.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';
import 'package:workpulse/domain/models/attribute_model.dart';

/// The app enforces no minimum window size, so a user can drag the window
/// down to almost nothing. These tests render each screen across the range a
/// user can actually produce and assert that nothing overflows — the failure
/// mode that hides content behind a yellow-and-black banner.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now().toUtc();

  final workspace = Workspace(
    id: 'ws-1',
    name: 'Default Workspace',
    createdAt: now,
    updatedAt: now,
  );

  final projects = [
    Project(
      id: 'p1',
      workspaceId: 'ws-1',
      name: 'A Deliberately Long Project Name For Truncation',
      description:
          'A long description that should truncate rather than overflow its '
          'card, however narrow the window becomes.',
      colorHex: '#0A84FF',
      createdAt: now,
      updatedAt: now,
    ),
    Project(
      id: 'p2',
      workspaceId: 'ws-1',
      name: 'Beta',
      colorHex: '#30D158',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  final categories = [
    Category(
      id: 'c1',
      workspaceId: 'ws-1',
      name: 'Engineering',
      iconName: 'code',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  final tags = [
    Tag(
      id: 't1',
      workspaceId: 'ws-1',
      name: 'urgent',
      colorHex: '#FF453A',
      createdAt: now,
    ),
  ];

  final people = [
    Person(
      id: 'per1',
      workspaceId: 'ws-1',
      name: 'Alice Smith',
      email: 'alice@a-fairly-long-domain-name.example.com',
      createdAt: now,
    ),
  ];

  final workItems = [
    WorkItem(
      id: 'w1',
      workspaceId: 'ws-1',
      projectId: 'p1',
      categoryId: 'c1',
      tagIds: const ['t1'],
      peopleIds: const ['per1'],
      name: 'Implement a work item with a name long enough to need clipping',
      notes: 'Some notes that also need to truncate cleanly.',
      createdAt: now,
      updatedAt: now,
    ),
    WorkItem(
      id: 'w2',
      workspaceId: 'ws-1',
      projectId: 'p2',
      categoryId: 'c1',
      name: 'Short one',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  final attributeDefs = [
    AttributeDefinition(
      id: 'a1',
      workspaceId: 'ws-1',
      key: 'jira_key',
      name: 'Jira Key',
      type: AttributeType.text,
      scope: AttributeScope.task,
      required: true,
      showInQuickCapture: true,
      reportable: true,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  Widget host(Widget screen) {
    return ProviderScope(
      overrides: [
        currentWorkspaceProvider.overrideWith(() => _FakeWorkspace(workspace)),
        projectsProvider.overrideWith(() => _FakeProjects(projects)),
        categoriesProvider.overrideWith(() => _FakeCategories(categories)),
        tagsProvider.overrideWith(() => _FakeTags(tags)),
        peopleProvider.overrideWith(() => _FakePeople(people)),
        workItemsProvider.overrideWith(() => _FakeWorkItems(workItems)),
        attributeDefinitionsProvider
            .overrideWith(() => _FakeAttributeDefs(attributeDefs)),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: screen,
      ),
    );
  }

  /// Widths a user can actually drag the window to. 1440 is a wide display,
  /// 1200x800 is the app's own default size, and 640 is well below anything
  /// reasonable — included precisely because nothing stops a user reaching it.
  const widths = <double>[1440, 1200, 1000, 860, 640];

  final screens = <String, Widget Function()>{
    'Work Items': () => const TasksView(),
    'Projects': () => const ProjectsView(),
    'Categories': () => const CategoriesView(),
    'Tags': () => const TagsView(),
    'People': () => const PeopleView(),
    'Attributes': () => const AttributeDefinitionsView(),
  };

  for (final entry in screens.entries) {
    for (final width in widths) {
      testWidgets(
          '${entry.key} lays out without overflow at ${width.toInt()}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(host(entry.value()));
        await tester.pumpAndSettle();

        // A layout overflow surfaces as a thrown FlutterError, which the test
        // binding records rather than rethrows.
        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} overflowed at ${width.toInt()}px',
        );
      });
    }
  }

  testWidgets('Work Items shows the inspector only when there is room for it',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;

    // Wide: the inspector pane stands by for a selection.
    tester.view.physicalSize = const Size(1400, 820);
    await tester.pumpWidget(host(const TasksView()));
    await tester.pumpAndSettle();
    expect(find.text('Select a work item'), findsOneWidget);

    // Narrow: no standing pane; detail moves inline on selection instead.
    tester.view.physicalSize = const Size(860, 820);
    await tester.pumpWidget(host(const TasksView()));
    await tester.pumpAndSettle();
    expect(find.text('Select a work item'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeWorkspace extends CurrentWorkspaceNotifier {
  final Workspace _w;
  _FakeWorkspace(this._w);
  @override
  Future<Workspace> build() async => _w;
}

class _FakeProjects extends ProjectsNotifier {
  final List<Project> _list;
  _FakeProjects(this._list);
  @override
  Future<List<Project>> build() async => _list;
}

class _FakeCategories extends CategoriesNotifier {
  final List<Category> _list;
  _FakeCategories(this._list);
  @override
  Future<List<Category>> build() async => _list;
}

class _FakeTags extends TagsNotifier {
  final List<Tag> _list;
  _FakeTags(this._list);
  @override
  Future<List<Tag>> build() async => _list;
}

class _FakePeople extends PeopleNotifier {
  final List<Person> _list;
  _FakePeople(this._list);
  @override
  Future<List<Person>> build() async => _list;
}

class _FakeWorkItems extends WorkItemsNotifier {
  final List<WorkItem> _list;
  _FakeWorkItems(this._list);
  @override
  Future<List<WorkItem>> build() async => _list;
}

class _FakeAttributeDefs extends AttributeDefinitionsNotifier {
  final List<AttributeDefinition> _list;
  _FakeAttributeDefs(this._list);
  @override
  Future<List<AttributeDefinition>> build() async => _list;
}
