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
  Future<void> confirmSwitch() async {
    confirmSwitchCalled = true;
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
      expect(find.text('25:10'), findsOneWidget);
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
    });
  });
}
