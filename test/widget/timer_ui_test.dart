import 'package:flutter/material.dart';
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
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tasks/providers/task_sessions_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/tasks/views/tasks_view.dart';
import 'package:workpulse/features/tasks/widgets/work_item_inspector.dart';
import 'package:workpulse/features/tasks/widgets/work_item_row.dart';
import 'package:workpulse/features/timer/models/timer_state.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/timer/views/active_timer_bar.dart';
import 'package:workpulse/features/timer/views/task_switch_dialog.dart';
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
}

class _FakeTimerNotifier extends TimerNotifier {
  final TimerState _initial;
  bool stopCalled = false;
  bool confirmSwitchCalled = false;
  String? switchNotes;

  _FakeTimerNotifier(this._initial);

  @override
  Future<TimerState> build() async => _initial;

  @override
  Future<Session?> stopTimer() async {
    stopCalled = true;
    state = const AsyncData(TimerState(status: TimerStatus.idle));
    return null;
  }

  @override
  Future<void> confirmSwitch({
    WorkItem? targetItem,
    String? notes,
    String? targetCategoryId,
    List<String>? targetTagIds,
    List<String>? targetPeopleIds,
  }) async {
    confirmSwitchCalled = true;
    switchNotes = notes;
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
    name: 'WorkPulse App',
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

  final testTaskA = WorkItem(
    id: 'task-a',
    workspaceId: testWorkspace.id,
    projectId: testProject.id,
    categoryId: testCategory.id,
    name: 'Build Timer Engine',
    createdAt: now,
    updatedAt: now,
  );

  final testTaskB = WorkItem(
    id: 'task-b',
    workspaceId: testWorkspace.id,
    projectId: testProject.id,
    categoryId: testCategory.id,
    name: 'Design Quick Capture',
    createdAt: now,
    updatedAt: now,
  );

  final testActiveSession = Session(
    id: 'sess-1',
    workItemId: testTaskA.id,
    startTime: now.subtract(const Duration(minutes: 25)),
    createdAt: now,
  );

  group('Timer UI Widget Tests', () {
    testWidgets(
        'ActiveTimerBar renders active task name and stop button when running',
        (tester) async {
      // The bar is a single fixed-height row that sheds optional content as
      // it narrows, so give it a realistic desktop width. The app's own
      // window is 1200x800.
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeTimer = _FakeTimerNotifier(
        TimerState(
          status: TimerStatus.running,
          activeWorkItem: testTaskA,
          activeSession: testActiveSession,
          elapsed: const Duration(minutes: 25, seconds: 10),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentWorkspaceProvider
                .overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
            projectsProvider
                .overrideWith(() => _FakeProjectsNotifier([testProject])),
            workItemsProvider.overrideWith(
                () => _FakeWorkItemsNotifier([testTaskA, testTaskB])),
            timerProvider.overrideWith(() => fakeTimer),
          ],
          child: const MaterialApp(
            themeMode: ThemeMode.dark,
            home: Scaffold(
              bottomNavigationBar: ActiveTimerBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TRACKING'), findsOneWidget);
      expect(find.text('Build Timer Engine'), findsOneWidget);
      expect(find.text('WorkPulse App'), findsOneWidget);
      expect(find.text('00:25:10'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);

      // Tap stop button
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      expect(fakeTimer.stopCalled, isTrue);
    });

    testWidgets('ActiveTimerBar sheds optional content on a narrow window',
        (tester) async {
      // Narrow enough to drop the project chip and the Switch button, but the
      // task name, elapsed time and Stop must always survive.
      tester.view.physicalSize = const Size(600, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeTimer = _FakeTimerNotifier(
        TimerState(
          status: TimerStatus.running,
          activeWorkItem: testTaskA,
          activeSession: testActiveSession,
          elapsed: const Duration(minutes: 25, seconds: 10),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentWorkspaceProvider
                .overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
            projectsProvider
                .overrideWith(() => _FakeProjectsNotifier([testProject])),
            workItemsProvider.overrideWith(
                () => _FakeWorkItemsNotifier([testTaskA, testTaskB])),
            timerProvider.overrideWith(() => fakeTimer),
          ],
          child: const MaterialApp(
            themeMode: ThemeMode.dark,
            home: Scaffold(
              bottomNavigationBar: ActiveTimerBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // No overflow banner: the bar fits whatever width it is given.
      expect(tester.takeException(), isNull);

      // Essentials survive.
      expect(find.text('Build Timer Engine'), findsOneWidget);
      expect(find.text('00:25:10'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);

      // Optional content is dropped rather than overflowing.
      expect(find.text('WorkPulse App'), findsNothing);
      expect(find.text('Switch'), findsNothing);
    });

    testWidgets('ActiveTimerBar is hidden when timer is idle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timerProvider.overrideWith(() =>
                _FakeTimerNotifier(const TimerState(status: TimerStatus.idle))),
          ],
          child: const MaterialApp(
            home: Scaffold(
              bottomNavigationBar: ActiveTimerBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TRACKING'), findsNothing);
      expect(find.text('Stop'), findsNothing);
    });

    testWidgets('TaskSwitchDialog renders comparison and confirms switch',
        (tester) async {
      final fakeTimer = _FakeTimerNotifier(
        TimerState(
          status: TimerStatus.switching,
          activeWorkItem: testTaskA,
          activeSession: testActiveSession,
          elapsed: const Duration(minutes: 15),
          pendingSwitchWorkItem: testTaskB,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timerProvider.overrideWith(() => fakeTimer),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: TaskSwitchDialog(
                currentItem: testTaskA,
                currentElapsed: const Duration(minutes: 15),
                targetItem: testTaskB,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Switch Active Task?'), findsOneWidget);
      expect(find.text('Build Timer Engine'), findsOneWidget);
      expect(find.text('Design Quick Capture'), findsOneWidget);
      expect(find.text('Confirm Switch'), findsOneWidget);

      await tester.tap(find.text('Confirm Switch'));
      await tester.pumpAndSettle();

      expect(fakeTimer.confirmSwitchCalled, isTrue);
    });

    testWidgets(
        'TaskSwitchDialog captures optional session note and confirms switch',
        (tester) async {
      final fakeTimer = _FakeTimerNotifier(
        TimerState(
          status: TimerStatus.switching,
          activeWorkItem: testTaskA,
          activeSession: testActiveSession,
          elapsed: const Duration(minutes: 15),
          pendingSwitchWorkItem: testTaskB,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timerProvider.overrideWith(() => fakeTimer),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: TaskSwitchDialog(
                currentItem: testTaskA,
                currentElapsed: const Duration(minutes: 15),
                targetItem: testTaskB,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter session note
      await tester.enterText(
          find.byType(TextField), 'Finished timer foundation');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Switch'));
      await tester.pumpAndSettle();

      expect(fakeTimer.confirmSwitchCalled, isTrue);
      expect(fakeTimer.switchNotes, 'Finished timer foundation');
    });

    testWidgets(
        'TasksView displays Play button and TRACKING status on active task card',
        (tester) async {
      final fakeTimer = _FakeTimerNotifier(
        TimerState(
          status: TimerStatus.running,
          activeWorkItem: testTaskA,
          activeSession: testActiveSession,
          elapsed: const Duration(minutes: 10),
        ),
      );

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
                () => _FakeWorkItemsNotifier([testTaskA, testTaskB])),
            timerProvider.overrideWith(() => fakeTimer),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const TasksView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Build Timer Engine'), findsOneWidget);
      expect(find.text('Design Quick Capture'), findsOneWidget);

      // Active task card has TRACKING badge and Stop icon
      expect(find.text('TRACKING'), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle), findsOneWidget);

      // Inactive task card has Play icon
      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);

      // Tapping Play on inactive task triggers TaskSwitchDialog
      await tester.tap(find.byIcon(Icons.play_circle_fill));
      await tester.pumpAndSettle();

      expect(find.text('Switch Active Task?'), findsOneWidget);
      expect(find.text('Switching To'), findsOneWidget);

      // Confirm switch
      await tester.tap(find.text('Confirm Switch'));
      await tester.pumpAndSettle();

      expect(fakeTimer.confirmSwitchCalled, isTrue);
    });

    /// Builds a TasksView with one work item that has a single session.
    Widget tasksViewWithSession(Session session, _FakeTimerNotifier fakeTimer) {
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
              .overrideWith(() => _FakeWorkItemsNotifier([testTaskA])),
          timerProvider.overrideWith(() => fakeTimer),
          sessionsForWorkItemProvider(testTaskA.id)
              .overrideWith((ref) async => [session]),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const TasksView(),
        ),
      );
    }

    final sampleSession = Session(
      id: 'session-1',
      workItemId: testTaskA.id,
      startTime: DateTime(2026, 8, 24, 9, 0),
      endTime: DateTime(2026, 8, 24, 10, 30),
      notes: 'Working on core timer engine',
      createdAt: DateTime(2026, 8, 24, 9, 0),
    );

    testWidgets(
        'TasksView shows a selected item\'s sessions in the inspector on a wide window',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        tasksViewWithSession(
          sampleSession,
          _FakeTimerNotifier(const TimerState(status: TimerStatus.idle)),
        ),
      );
      await tester.pumpAndSettle();

      // Nothing selected yet: the inspector prompts instead of showing detail.
      expect(find.text('Select a work item'), findsOneWidget);
      expect(find.text('Working on core timer engine'), findsNothing);

      await tester.tap(find.text('Build Timer Engine'));
      await tester.pumpAndSettle();

      // The inspector opens beside the list, without displacing it.
      expect(find.byType(WorkItemInspector), findsOneWidget);
      expect(find.text('SESSIONS (1)'), findsOneWidget);
      expect(find.text('Working on core timer engine'), findsOneWidget);
      expect(find.text('01:30:00'), findsOneWidget);
      expect(find.text('Select a work item'), findsNothing);

      // Closing returns to the placeholder.
      await tester.tap(find.byTooltip('Close inspector'));
      await tester.pumpAndSettle();
      expect(find.text('Working on core timer engine'), findsNothing);
      expect(find.text('Select a work item'), findsOneWidget);
    });

    testWidgets(
        'TasksView falls back to inline detail when too narrow for two panes',
        (tester) async {
      // Below the two-pane breakpoint the inspector has nowhere to go, so the
      // same detail expands under the row instead. No interaction is lost.
      tester.view.physicalSize = const Size(820, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        tasksViewWithSession(
          sampleSession,
          _FakeTimerNotifier(const TimerState(status: TimerStatus.idle)),
        ),
      );
      await tester.pumpAndSettle();

      // There is no standing inspector pane at this width.
      expect(find.text('Select a work item'), findsNothing);
      expect(find.byType(WorkItemInspector), findsNothing);
      expect(find.text('Working on core timer engine'), findsNothing);

      // Once expanded the name appears in both the row and the inspector
      // header, so aim the taps at the row specifically.
      final rowTitle = find.descendant(
        of: find.byType(WorkItemRow),
        matching: find.text('Build Timer Engine'),
      );

      await tester.tap(rowTitle);
      await tester.pumpAndSettle();

      expect(find.byType(WorkItemInspector), findsOneWidget);
      expect(find.text('SESSIONS (1)'), findsOneWidget);
      expect(find.text('Working on core timer engine'), findsOneWidget);

      // Tapping the row again collapses it.
      await tester.tap(rowTitle);
      await tester.pumpAndSettle();
      expect(find.byType(WorkItemInspector), findsNothing);
      expect(find.text('Working on core timer engine'), findsNothing);
    });
  });
}
