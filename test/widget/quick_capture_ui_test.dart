import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/quick_capture/views/quick_capture_dialog.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/timer/models/timer_state.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

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
}

class _FakeCategoriesNotifier extends CategoriesNotifier {
  final List<Category> _list;
  _FakeCategoriesNotifier(this._list);
  @override
  Future<List<Category>> build() async => _list;
}

class _FakeTagsNotifier extends TagsNotifier {
  @override
  Future<List<Tag>> build() async => [];
}

class _FakePeopleNotifier extends PeopleNotifier {
  @override
  Future<List<Person>> build() async => [];
}

class _FakeWorkItemsNotifier extends WorkItemsNotifier {
  final List<WorkItem> _list;
  _FakeWorkItemsNotifier(this._list);
  @override
  Future<List<WorkItem>> build() async => _list;

  @override
  Future<WorkItem> createWorkItem({
    required String projectId,
    required String categoryId,
    required String name,
    String? notes,
    List<String> tagIds = const [],
    List<String> peopleIds = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final item = WorkItem(
      id: 'task-created',
      workspaceId: 'ws-1',
      projectId: projectId,
      categoryId: categoryId,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    _list.add(item);
    state = AsyncData(List.from(_list));
    return item;
  }
}

class _FakeTimerNotifier extends TimerNotifier {
  WorkItem? startedTask;

  @override
  Future<TimerState> build() async =>
      const TimerState(status: TimerStatus.idle);

  @override
  Future<void> startTimer(
    WorkItem workItem, {
    String? categoryId,
    List<String> tagIds = const [],
    List<String> peopleIds = const [],
    String? notes,
  }) async {
    startedTask = workItem;
    state = AsyncData(
      TimerState(
        status: TimerStatus.running,
        activeWorkItem: workItem,
        activeSession: Session(
          id: 'sess-new',
          workItemId: workItem.id,
          categoryId: categoryId ?? workItem.categoryId,
          startTime: DateTime.now().toUtc(),
          createdAt: DateTime.now().toUtc(),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now().toUtc();
  final testWorkspace = Workspace(
    id: 'ws-1',
    name: 'Default',
    createdAt: now,
    updatedAt: now,
  );

  final testProject = Project(
    id: 'proj-1',
    workspaceId: testWorkspace.id,
    name: 'App Core',
    colorHex: '#0A84FF',
    createdAt: now,
    updatedAt: now,
  );

  final testCategory = Category(
    id: 'cat-1',
    workspaceId: testWorkspace.id,
    name: 'Engineering',
    iconName: 'code',
    createdAt: now,
    updatedAt: now,
  );

  final testTask1 = WorkItem(
    id: 'task-1',
    workspaceId: testWorkspace.id,
    projectId: testProject.id,
    categoryId: testCategory.id,
    name: 'Implement Quick Capture',
    createdAt: now,
    updatedAt: now,
  );

  final testTask2 = WorkItem(
    id: 'task-2',
    workspaceId: testWorkspace.id,
    projectId: testProject.id,
    categoryId: testCategory.id,
    name: 'Review Security Policy',
    createdAt: now,
    updatedAt: now,
  );

  Widget createTestApp(FakeTimerProviderContainer container) {
    return ProviderScope(
      overrides: [
        currentWorkspaceProvider
            .overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
        projectsProvider
            .overrideWith(() => _FakeProjectsNotifier([testProject])),
        categoriesProvider
            .overrideWith(() => _FakeCategoriesNotifier([testCategory])),
        tagsProvider.overrideWith(() => _FakeTagsNotifier()),
        peopleProvider.overrideWith(() => _FakePeopleNotifier()),
        workItemsProvider
            .overrideWith(() => _FakeWorkItemsNotifier([testTask1, testTask2])),
        timerProvider.overrideWith(() => container.fakeTimer),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: QuickCaptureDialog(),
        ),
      ),
    );
  }

  group('QuickCaptureDialog UI Widget Tests', () {
    testWidgets(
        'renders search input, shortcut badges, and matching tasks list',
        (tester) async {
      final container = FakeTimerProviderContainer();
      await tester.pumpWidget(createTestApp(container));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Implement Quick Capture'), findsOneWidget);
      expect(find.text('Review Security Policy'), findsOneWidget);
      expect(find.text('↵ Track'), findsOneWidget);
      expect(find.text('esc'), findsOneWidget);
      expect(find.text('App Core'), findsWidgets);
    });

    testWidgets(
        'typing search query filters tasks in real-time and shows create option',
        (tester) async {
      final container = FakeTimerProviderContainer();
      await tester.pumpWidget(createTestApp(container));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Quick');
      await tester.pumpAndSettle();

      expect(find.text('Implement Quick Capture'), findsOneWidget);
      expect(find.text('Review Security Policy'), findsNothing);

      // Type a completely new task name
      await tester.enterText(find.byType(TextField), 'Deploy to Production');
      await tester.pumpAndSettle();

      expect(find.textContaining('Deploy to Production'), findsOneWidget);
    });

    testWidgets('pressing Enter on selected task starts timer', (tester) async {
      final container = FakeTimerProviderContainer();
      await tester.pumpWidget(createTestApp(container));
      await tester.pumpAndSettle();

      // Implement Quick Capture is at index 0
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(container.fakeTimer.startedTask, isNotNull);
      expect(container.fakeTimer.startedTask!.id, testTask1.id);
    });

    testWidgets('creating and starting new task via enter key', (tester) async {
      final container = FakeTimerProviderContainer();
      await tester.pumpWidget(createTestApp(container));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Brand New Task');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(container.fakeTimer.startedTask, isNotNull);
      expect(container.fakeTimer.startedTask!.name, 'Brand New Task');
    });

    testWidgets('renders 2-column dropdowns with Project and Category labels',
        (tester) async {
      final container = FakeTimerProviderContainer();
      await tester.pumpWidget(createTestApp(container));
      await tester.pumpAndSettle();

      // Check labels exist
      expect(find.text('Project'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);

      // Check values displayed in triggers
      expect(find.text('App Core'), findsWidgets);
      expect(find.text('Engineering'), findsWidgets);
    });

    testWidgets('keyboard tab and arrow key opens dropdown', (tester) async {
      final container = FakeTimerProviderContainer();
      await tester.pumpWidget(createTestApp(container));
      await tester.pumpAndSettle();

      // Tab from search field to first dropdown (Project)
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Press ArrowDown to open the dropdown menu
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Menu should be open with menu item
      expect(find.byType(MenuItemButton), findsWidgets);
    });
  });
}

class FakeTimerProviderContainer {
  final fakeTimer = _FakeTimerNotifier();
}
