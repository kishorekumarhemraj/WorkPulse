import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/platform/window_service.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/work_item_plan.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/quick_capture/views/quick_capture_standalone_view.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/timer/models/timer_state.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';
import 'package:workpulse/main.dart';

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
    FinancialClassification classification = FinancialClassification.none,
    WorkItemPlan plan = const WorkItemPlan.unplanned(),
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
      plan: plan,
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
    name: 'Implement Standalone Quick Capture',
    createdAt: now,
    updatedAt: now,
  );

  final testTask2 = WorkItem(
    id: 'task-2',
    workspaceId: testWorkspace.id,
    projectId: testProject.id,
    categoryId: testCategory.id,
    name: 'Verify Focus Isolation',
    createdAt: now,
    updatedAt: now,
  );

  Widget createStandaloneApp({
    required _FakeTimerNotifier timerNotifier,
    VoidCallback? onClose,
  }) {
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
        unfilteredWorkItemsProvider
            .overrideWith((ref) async => [testTask1, testTask2]),
        timerProvider.overrideWith(() => timerNotifier),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: QuickCaptureStandaloneView(
          onClose: onClose,
        ),
      ),
    );
  }

  group('QuickCaptureStandaloneView Widget Tests', () {
    testWidgets(
        'renders search input, shortcut badges, and matching tasks list',
        (tester) async {
      final timerNotifier = _FakeTimerNotifier();
      await tester
          .pumpWidget(createStandaloneApp(timerNotifier: timerNotifier));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Implement Standalone Quick Capture'), findsOneWidget);
      expect(find.text('Verify Focus Isolation'), findsOneWidget);
      expect(find.text('↵ Track'), findsOneWidget);
      expect(find.text('esc'), findsOneWidget);
      expect(find.text('App Core'), findsWidgets);
    });

    testWidgets('pressing Escape invokes onClose callback', (tester) async {
      bool closed = false;
      final timerNotifier = _FakeTimerNotifier();
      await tester.pumpWidget(
        createStandaloneApp(
          timerNotifier: timerNotifier,
          onClose: () => closed = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });

    testWidgets(
        'selecting existing task and pressing Enter starts timer and closes',
        (tester) async {
      bool closed = false;
      final timerNotifier = _FakeTimerNotifier();
      await tester.pumpWidget(
        createStandaloneApp(
          timerNotifier: timerNotifier,
          onClose: () => closed = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(timerNotifier.startedTask, isNotNull);
      expect(timerNotifier.startedTask!.id, testTask1.id);
      expect(closed, isTrue);
    });

    testWidgets(
        'typing query and pressing Enter creates new task and starts timer',
        (tester) async {
      bool closed = false;
      final timerNotifier = _FakeTimerNotifier();
      await tester.pumpWidget(
        createStandaloneApp(
          timerNotifier: timerNotifier,
          onClose: () => closed = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Fix Focus Bug');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(timerNotifier.startedTask, isNotNull);
      expect(timerNotifier.startedTask!.name, 'Fix Focus Bug');
      expect(closed, isTrue);
    });

    testWidgets('renders 2-column dropdowns with Project and Category labels',
        (tester) async {
      final timerNotifier = _FakeTimerNotifier();
      await tester
          .pumpWidget(createStandaloneApp(timerNotifier: timerNotifier));
      await tester.pumpAndSettle();

      expect(find.text('Project'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('App Core'), findsWidgets);
      expect(find.text('Engineering'), findsWidgets);
    });

    testWidgets(
        'WorkPulseApp dynamically renders QuickCaptureStandaloneView on WindowMode.quickCapture',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final noOpWindow = NoOpWindowService();
      final timerNotifier = _FakeTimerNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentWorkspaceProvider
                .overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
            projectsProvider
                .overrideWith(() => _FakeProjectsNotifier([testProject])),
            categoriesProvider
                .overrideWith(() => _FakeCategoriesNotifier([testCategory])),
            tagsProvider.overrideWith(() => _FakeTagsNotifier()),
            peopleProvider.overrideWith(() => _FakePeopleNotifier()),
            workItemsProvider.overrideWith(
                () => _FakeWorkItemsNotifier([testTask1, testTask2])),
            timerProvider.overrideWith(() => timerNotifier),
          ],
          child: WorkPulseApp(
            windowService: noOpWindow,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In Dashboard mode, MainShellView is rendered
      expect(find.byType(QuickCaptureStandaloneView), findsNothing);

      // Switch to Quick Capture mode
      await noOpWindow.openQuickCapture();
      await tester.pumpAndSettle();

      // Now QuickCaptureStandaloneView is rendered directly
      expect(find.byType(QuickCaptureStandaloneView), findsOneWidget);

      // Close quick capture
      await noOpWindow.closeQuickCapture();
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureStandaloneView), findsNothing);
    });
  });
}
