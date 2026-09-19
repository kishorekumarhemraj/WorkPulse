import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/work_item_merge_service.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/tasks/providers/task_sessions_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/tasks/views/tasks_view.dart';
import 'package:workpulse/features/tasks/views/work_item_merge_dialog.dart';
import 'package:workpulse/features/tasks/widgets/work_item_inspector.dart';
import 'package:workpulse/features/timer/models/timer_state.dart';
import 'package:workpulse/features/timer/providers/task_duration_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

class _FakeWorkspace extends CurrentWorkspaceNotifier {
  final Workspace _ws;
  _FakeWorkspace(this._ws);
  @override
  Future<Workspace> build() async => _ws;
}

class _FakeProjects extends ProjectsNotifier {
  final List<Project> _projects;
  _FakeProjects(this._projects);
  @override
  Future<List<Project>> build() async => _projects;
}

class _FakeCategories extends CategoriesNotifier {
  final List<Category> _categories;
  _FakeCategories(this._categories);
  @override
  Future<List<Category>> build() async => _categories;
}

class _FakeWorkItemsNotifier extends WorkItemsNotifier {
  final List<WorkItem> _items;
  WorkItemMergeRequest? lastMergeRequest;

  _FakeWorkItemsNotifier(this._items);

  @override
  Future<List<WorkItem>> build() async => _items;

  @override
  Future<WorkItemMergeResult> mergeWorkItems(
      WorkItemMergeRequest request) async {
    lastMergeRequest = request;
    final target = _items.firstWhere((i) => i.id == request.targetWorkItemId);
    return WorkItemMergeResult(
      targetWorkItem: target,
      sessionsMovedCount: 3,
      sourceDeleted: request.deleteSource,
    );
  }
}

class _FakeTimer extends TimerNotifier {
  @override
  Future<TimerState> build() async =>
      const TimerState(status: TimerStatus.idle);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 8, 26);

  final workspace = Workspace(
    id: 'ws-1',
    name: 'Default Workspace',
    createdAt: now,
    updatedAt: now,
  );

  final project = Project(
    id: 'p1',
    workspaceId: 'ws-1',
    name: 'Core System',
    colorHex: '#0A84FF',
    createdAt: now,
    updatedAt: now,
  );

  final category = Category(
    id: 'c1',
    workspaceId: 'ws-1',
    name: 'Backend',
    iconName: 'code',
    createdAt: now,
    updatedAt: now,
  );

  final itemA = WorkItem(
    id: 'task-a',
    workspaceId: 'ws-1',
    name: 'Migrate DB Schema',
    projectId: 'p1',
    categoryId: 'c1',
    createdAt: now,
    updatedAt: now,
  );

  final itemB = WorkItem(
    id: 'task-b',
    workspaceId: 'ws-1',
    name: 'Database Migration V2',
    projectId: 'p1',
    categoryId: 'c1',
    createdAt: now,
    updatedAt: now,
  );

  final itemC = WorkItem(
    id: 'task-c',
    workspaceId: 'ws-1',
    name: 'Frontend Polish',
    projectId: 'p1',
    categoryId: 'c1',
    createdAt: now,
    updatedAt: now,
  );

  late _FakeWorkItemsNotifier fakeWorkItems;

  Widget hostDialog({
    required WorkItem sourceItem,
    WorkItem? targetItem,
  }) {
    fakeWorkItems = _FakeWorkItemsNotifier([itemA, itemB, itemC]);
    return ProviderScope(
      overrides: [
        currentWorkspaceProvider.overrideWith(() => _FakeWorkspace(workspace)),
        projectsProvider.overrideWith(() => _FakeProjects([project])),
        categoriesProvider.overrideWith(() => _FakeCategories([category])),
        workItemsProvider.overrideWith(() => fakeWorkItems),
        unfilteredWorkItemsProvider
            .overrideWith((ref) => [itemA, itemB, itemC]),
        timerProvider.overrideWith(() => _FakeTimer()),
        sessionsForWorkItemProvider
            .overrideWith((ref, id) => Future.value(const <Session>[])),
        taskTotalDurationProvider
            .overrideWith((ref, id) => Future.value(Duration.zero)),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => WorkItemMergeDialog.show(
                ctx,
                sourceItem: sourceItem,
                targetItem: targetItem,
              ),
              child: const Text('Open Merge Dialog'),
            ),
          ),
        ),
      ),
    );
  }

  Widget hostTasksView() {
    fakeWorkItems = _FakeWorkItemsNotifier([itemA, itemB]);
    return ProviderScope(
      overrides: [
        currentWorkspaceProvider.overrideWith(() => _FakeWorkspace(workspace)),
        projectsProvider.overrideWith(() => _FakeProjects([project])),
        categoriesProvider.overrideWith(() => _FakeCategories([category])),
        workItemsProvider.overrideWith(() => fakeWorkItems),
        unfilteredWorkItemsProvider.overrideWith((ref) => [itemA, itemB]),
        timerProvider.overrideWith(() => _FakeTimer()),
        sessionsForWorkItemProvider
            .overrideWith((ref, id) => Future.value(const <Session>[])),
        workItemSessionRecordsProvider.overrideWith(
            (ref, id) => Future.value(const <SessionExportRecord>[])),
        taskTotalDurationProvider
            .overrideWith((ref, id) => Future.value(Duration.zero)),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const TasksView(),
      ),
    );
  }

  group('WorkItemMergeDialog Widget Tests', () {
    testWidgets('renders dialog with source item and searchable candidate list',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(hostDialog(sourceItem: itemA));
      await tester.tap(find.text('Open Merge Dialog'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Merge Work Items'), findsOneWidget);
      expect(find.text('Source Work Item (will be deleted / archived)'),
          findsOneWidget);
      expect(find.text('Migrate DB Schema'), findsOneWidget);

      // Candidates should list itemB and itemC, but NOT itemA (the source itself)
      expect(find.text('Database Migration V2'), findsOneWidget);
      expect(find.text('Frontend Polish'), findsOneWidget);

      // Filter candidates using search field
      await tester.enterText(
          find.widgetWithText(
              TextField, 'Search work item by name, project, category…'),
          'Polish');
      await tester.pumpAndSettle();

      expect(find.text('Frontend Polish'), findsOneWidget);
      expect(find.text('Database Migration V2'), findsNothing);
    });

    testWidgets(
        'selecting candidate displays destination card, summary, and enables merge',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(hostDialog(sourceItem: itemA));
      await tester.tap(find.text('Open Merge Dialog'));
      await tester.pumpAndSettle();

      // Click select on Database Migration V2
      final selectButtons = find.widgetWithText(TextButton, 'Select');
      expect(selectButtons, findsWidgets);
      await tester.tap(selectButtons.first);
      await tester.pumpAndSettle();

      // Destination card should appear
      expect(find.text('Destination Work Item (will keep & receive sessions)'),
          findsOneWidget);
      expect(find.text('Database Migration V2'), findsOneWidget);
      expect(find.text('Impact Summary'), findsOneWidget);

      // Click Merge Work Items button
      final mergeBtn = find.widgetWithText(ElevatedButton, 'Merge Work Items');
      expect(mergeBtn, findsOneWidget);
      await tester.tap(mergeBtn);
      await tester.pumpAndSettle();

      // Verify notifier was called with proper merge parameters
      expect(fakeWorkItems.lastMergeRequest, isNotNull);
      expect(fakeWorkItems.lastMergeRequest!.sourceWorkItemId, 'task-a');
      expect(fakeWorkItems.lastMergeRequest!.targetWorkItemId, 'task-b');
      expect(fakeWorkItems.lastMergeRequest!.deleteSource, isTrue);
      expect(fakeWorkItems.lastMergeRequest!.combineNotes, isTrue);
      expect(fakeWorkItems.lastMergeRequest!.combineTags, isTrue);

      // Dialog should close and SnackBar be displayed
      expect(find.byType(WorkItemMergeDialog), findsNothing);
      expect(
          find.textContaining(
              'Successfully merged "Migrate DB Schema" into "Database Migration V2"'),
          findsOneWidget);
    });

    testWidgets('swapping direction flips source and target items',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(hostDialog(sourceItem: itemA, targetItem: itemB));
      await tester.tap(find.text('Open Merge Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Swap Direction'), findsOneWidget);

      // Swap
      await tester.tap(find.text('Swap Direction'));
      await tester.pumpAndSettle();

      // Now itemB is source, itemA is destination
      // Submit merge
      await tester.tap(find.widgetWithText(ElevatedButton, 'Merge Work Items'));
      await tester.pumpAndSettle();

      expect(fakeWorkItems.lastMergeRequest!.sourceWorkItemId, 'task-b');
      expect(fakeWorkItems.lastMergeRequest!.targetWorkItemId, 'task-a');
    });

    testWidgets('toggling options modifies merge request', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(hostDialog(sourceItem: itemA, targetItem: itemB));
      await tester.tap(find.text('Open Merge Dialog'));
      await tester.pumpAndSettle();

      // Uncheck delete source (to archive instead)
      final deleteTile = find.widgetWithText(
          CheckboxListTile, 'Delete source work item permanently');
      await tester.ensureVisible(deleteTile);
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();

      // Check text changed to archive
      expect(find.text('Archive source work item instead of deleting'),
          findsOneWidget);

      // Submit merge
      final mergeBtn = find.widgetWithText(ElevatedButton, 'Merge Work Items');
      await tester.ensureVisible(mergeBtn);
      await tester.tap(mergeBtn);
      await tester.pumpAndSettle();

      expect(fakeWorkItems.lastMergeRequest!.deleteSource, isFalse);
    });
  });

  group('TasksView merge integration', () {
    testWidgets(
        'triggering Merge into... from row popup opens WorkItemMergeDialog',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(hostTasksView());
      await tester.pumpAndSettle();

      // Find the row for Migrate DB Schema
      final moreButtons = find.byTooltip('More actions');
      expect(moreButtons, findsWidgets);

      // Tap the first row's more actions button
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Merge into…'), findsOneWidget);
      await tester.tap(find.text('Merge into…'));
      await tester.pumpAndSettle();

      // Merge dialog should be open
      expect(find.byType(WorkItemMergeDialog), findsOneWidget);
      expect(find.text('Migrate DB Schema'), findsWidgets);
    });

    testWidgets(
        'triggering Merge from WorkItemInspector opens WorkItemMergeDialog',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(hostTasksView());
      await tester.pumpAndSettle();

      // Click on row to open inspector
      await tester.tap(find.text('Migrate DB Schema'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkItemInspector), findsOneWidget);

      final mergeIconBtn = find.byTooltip('Merge work item');
      expect(mergeIconBtn, findsOneWidget);

      await tester.tap(mergeIconBtn);
      await tester.pumpAndSettle();

      // Merge dialog should be open
      expect(find.byType(WorkItemMergeDialog), findsOneWidget);
      expect(find.text('Migrate DB Schema'), findsWidgets);
    });
  });
}
