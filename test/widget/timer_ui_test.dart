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
  Future<void> confirmSwitch({WorkItem? targetItem, String? notes}) async {
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
    testWidgets('ActiveTimerBar renders active task name and stop button when running', (tester) async {
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
            currentWorkspaceProvider.overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
            projectsProvider.overrideWith(() => _FakeProjectsNotifier([testProject])),
            workItemsProvider.overrideWith(() => _FakeWorkItemsNotifier([testTaskA, testTaskB])),
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

    testWidgets('ActiveTimerBar is hidden when timer is idle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timerProvider.overrideWith(() => _FakeTimerNotifier(const TimerState(status: TimerStatus.idle))),
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

    testWidgets('TaskSwitchDialog renders comparison and confirms switch', (tester) async {
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

    testWidgets('TaskSwitchDialog captures optional session note and confirms switch', (tester) async {
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
      await tester.enterText(find.byType(TextField), 'Finished timer foundation');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Switch'));
      await tester.pumpAndSettle();

      expect(fakeTimer.confirmSwitchCalled, isTrue);
      expect(fakeTimer.switchNotes, 'Finished timer foundation');
    });

    testWidgets('TasksView displays Play button and TRACKING status on active task card', (tester) async {
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
            currentWorkspaceProvider.overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
            projectsProvider.overrideWith(() => _FakeProjectsNotifier([testProject])),
            categoriesProvider.overrideWith(() => _FakeCategoriesNotifier([testCategory])),
            tagsProvider.overrideWith(() => _FakeTagsNotifier()),
            peopleProvider.overrideWith(() => _FakePeopleNotifier()),
            workItemsProvider.overrideWith(() => _FakeWorkItemsNotifier([testTaskA, testTaskB])),
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

    testWidgets('TasksView expands and collapses sessions when clicking Sessions badge', (tester) async {
      final sampleSession = Session(
        id: 'session-1',
        workItemId: testTaskA.id,
        startTime: DateTime(2026, 8, 24, 9, 0),
        endTime: DateTime(2026, 8, 24, 10, 30),
        notes: 'Working on core timer engine',
        createdAt: DateTime(2026, 8, 24, 9, 0),
      );

      final fakeTimer = _FakeTimerNotifier(
        const TimerState(status: TimerStatus.idle),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentWorkspaceProvider.overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
            projectsProvider.overrideWith(() => _FakeProjectsNotifier([testProject])),
            categoriesProvider.overrideWith(() => _FakeCategoriesNotifier([testCategory])),
            tagsProvider.overrideWith(() => _FakeTagsNotifier()),
            peopleProvider.overrideWith(() => _FakePeopleNotifier()),
            workItemsProvider.overrideWith(() => _FakeWorkItemsNotifier([testTaskA])),
            timerProvider.overrideWith(() => fakeTimer),
            sessionsForWorkItemProvider(testTaskA.id).overrideWith((ref) async => [sampleSession]),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const TasksView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Sessions badge is visible with count
      expect(find.text('Sessions (1)'), findsOneWidget);

      // Session detail is initially collapsed
      expect(find.text('Working on core timer engine'), findsNothing);

      // Tap on Sessions badge to expand
      await tester.tap(find.text('Sessions (1)'));
      await tester.pumpAndSettle();

      // Now session row is visible with note and duration
      expect(find.text('Working on core timer engine'), findsOneWidget);
      expect(find.text('01:30:00'), findsOneWidget);

      // Tap Sessions badge again to collapse
      await tester.tap(find.text('Sessions (1)'));
      await tester.pumpAndSettle();

      // Session detail is collapsed again
      expect(find.text('Working on core timer engine'), findsNothing);
    });
  });
}
