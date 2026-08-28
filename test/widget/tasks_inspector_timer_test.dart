import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/features/tasks/providers/task_sessions_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/tasks/views/tasks_view.dart';
import 'package:workpulse/features/tasks/widgets/work_item_inspector.dart';
import 'package:workpulse/features/tasks/widgets/work_item_row.dart';
import 'package:workpulse/features/timer/models/timer_state.dart';
import 'package:workpulse/features/timer/providers/task_duration_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

/// Pressing play is a statement about what you are working on now, so the
/// inspector has to follow it. Before this, it kept describing whatever row
/// was last *clicked* — so stop, then start something else, and the detail
/// pane confidently showed the wrong task.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 8, 26);

  final workspace = Workspace(
    id: 'ws-1',
    name: 'Default',
    createdAt: now,
    updatedAt: now,
  );

  final project = Project(
    id: 'p1',
    workspaceId: 'ws-1',
    name: 'Platform',
    colorHex: '#0A84FF',
    createdAt: now,
    updatedAt: now,
  );

  final category = Category(
    id: 'c1',
    workspaceId: 'ws-1',
    name: 'Engineering',
    iconName: 'code',
    createdAt: now,
    updatedAt: now,
  );

  WorkItem item(String id, String name) => WorkItem(
        id: id,
        workspaceId: 'ws-1',
        name: name,
        projectId: 'p1',
        categoryId: 'c1',
        createdAt: now,
        updatedAt: now,
      );

  final alpha = item('t1', 'Alpha task');
  final beta = item('t2', 'Beta task');

  late _FakeTimer timer;

  Widget host() => ProviderScope(
        overrides: [
          currentWorkspaceProvider
              .overrideWith(() => _FakeWorkspace(workspace)),
          projectsProvider.overrideWith(() => _FakeProjects([project])),
          categoriesProvider.overrideWith(() => _FakeCategories([category])),
          workItemsProvider.overrideWith(() => _FakeWorkItems([alpha, beta])),
          timerProvider.overrideWith(() => timer),
          // The inspector reads both; neither is what these tests are about.
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

  /// The name as the *inspector* renders it — the row shows it too.
  Finder inspectorShows(String name) => find.descendant(
        of: find.byType(WorkItemInspector),
        matching: find.text(name),
      );

  Future<void> pumpTasks(WidgetTester tester) async {
    // Wide enough for the two-pane layout that has an inspector at all.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
  }

  /// The list row for [name].
  ///
  /// Scoped to the row widget because once the inspector is open it renders
  /// the same name, so matching on the text alone finds two places.
  Finder rowFor(String name) => find.ancestor(
        of: find.text(name),
        matching: find.byType(WorkItemRow),
      );

  Future<void> pressPlayOn(WidgetTester tester, String name) async {
    expect(rowFor(name), findsOneWidget, reason: 'no list row for $name');
    await tester.tap(
      find.descendant(
        of: rowFor(name),
        matching: find.byIcon(Icons.play_circle_fill),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The row's stop control — not the inspector's, which uses the outlined
  /// icon.
  Future<void> pressStopOn(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: rowFor(name),
        matching: find.byIcon(Icons.stop_circle),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => timer = _FakeTimer());

  group('the inspector follows the running timer', () {
    testWidgets('starting a task reveals it, with nothing selected before',
        (tester) async {
      await pumpTasks(tester);

      expect(find.byType(WorkItemInspector), findsNothing);

      await pressPlayOn(tester, 'Alpha task');

      expect(inspectorShows('Alpha task'), findsOneWidget);
    });

    testWidgets('stop, then start another task, moves the inspector across',
        (tester) async {
      await pumpTasks(tester);

      await pressPlayOn(tester, 'Alpha task');
      expect(inspectorShows('Alpha task'), findsOneWidget);

      // Stopping leaves the selection where it is.
      await pressStopOn(tester, 'Alpha task');
      expect(inspectorShows('Alpha task'), findsOneWidget);

      // ...and starting the other one brings the inspector with it. This is
      // the sequence that used to leave the wrong task on screen.
      await pressPlayOn(tester, 'Beta task');

      expect(inspectorShows('Beta task'), findsOneWidget);
      expect(inspectorShows('Alpha task'), findsNothing);
    });

    testWidgets('a start that never happened does not move the selection',
        (tester) async {
      timer.refuseToStart = true;
      await pumpTasks(tester);

      await pressPlayOn(tester, 'Alpha task');

      // A switch the user cancels in the confirmation dialog lands here too:
      // nothing is tracking, so nothing is revealed.
      expect(find.byType(WorkItemInspector), findsNothing);
    });
  });

  group('WorkItemInspector sessions rendering', () {
    testWidgets('renders session metadata chips and note block',
        (tester) async {
      final sess = Session(
        id: 'sess-1',
        workItemId: alpha.id,
        categoryId: category.id,
        startTime: now.subtract(const Duration(minutes: 90)),
        endTime: now,
        notes: 'Refactored state layer',
        createdAt: now.subtract(const Duration(minutes: 90)),
      );

      final record = SessionExportRecord(
        session: sess,
        workItem: alpha,
        project: project,
        category: category,
        grossDuration: const Duration(minutes: 90),
        idleDuration: Duration.zero,
        netActiveDuration: const Duration(minutes: 90),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentWorkspaceProvider
                .overrideWith(() => _FakeWorkspace(workspace)),
            workItemSessionRecordsProvider
                .overrideWith((ref, id) => Future.value([record])),
            taskTotalDurationProvider
                .overrideWith((ref, id) => Future.value(const Duration(minutes: 90))),
            timerProvider.overrideWith(() => timer),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: WorkItemInspector(
                item: alpha,
                project: project,
                category: category,
                tags: const [],
                people: const [],
                peopleMap: const {},
                onEdit: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SESSIONS (1)'), findsOneWidget);
      expect(find.text('Engineering'), findsWidgets);
      // Project is omitted from per-session chips
      expect(find.text('Refactored state layer'), findsOneWidget);
      expect(find.text('01:30:00'), findsOneWidget);
    });
  });
}

class _FakeTimer extends TimerNotifier {
  /// Stands in for a switch the user cancels: the tap happens, the timer does
  /// not start.
  bool refuseToStart = false;

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
    if (refuseToStart) return;
    state = AsyncData(
      TimerState(
        status: TimerStatus.running,
        activeWorkItem: workItem,
        activeSession: Session(
          id: 'sess-${workItem.id}',
          workItemId: workItem.id,
          startTime: DateTime.utc(2026, 8, 26, 9),
          createdAt: DateTime.utc(2026, 8, 26, 9),
        ),
      ),
    );
  }

  @override
  Future<Session?> stopTimer() async {
    state = const AsyncData(TimerState(status: TimerStatus.idle));
    return null;
  }
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

class _FakeWorkItems extends WorkItemsNotifier {
  final List<WorkItem> _list;
  _FakeWorkItems(this._list);
  @override
  Future<List<WorkItem>> build() async => _list;
}
