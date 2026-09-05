import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/calendar_date.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/work_item_plan.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/planner/views/planner_view.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

void main() {
  group('PlannerView Widget Tests', () {
    final now = DateTime.now().toUtc();
    final today = CalendarDate.fromLocal(DateTime.now());

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
      colorHex: '#0A84FF',
      createdAt: now,
      updatedAt: now,
    );
    final testCategory = Category(
      id: 'cat-1',
      workspaceId: 'ws-1',
      name: 'Engineering',
      iconName: 'code',
      createdAt: now,
      updatedAt: now,
    );

    final itemOverdue = WorkItem(
      id: 'item-overdue',
      workspaceId: 'ws-1',
      name: 'Late Project Delivery',
      projectId: 'proj-1',
      categoryId: 'cat-1',
      plan: WorkItemPlan(due: today.addDays(-3)),
      createdAt: now,
      updatedAt: now,
    );

    final itemDueToday = WorkItem(
      id: 'item-due-today',
      workspaceId: 'ws-1',
      name: 'Urgent Fix Due Today',
      projectId: 'proj-1',
      categoryId: 'cat-1',
      plan: WorkItemPlan(due: today),
      createdAt: now,
      updatedAt: now,
    );

    final itemStartingToday = WorkItem(
      id: 'item-starting-today',
      workspaceId: 'ws-1',
      name: 'Kickoff Starting Today',
      projectId: 'proj-1',
      categoryId: 'cat-1',
      plan: WorkItemPlan(
        plannedStart: today,
        due: today.addDays(10),
      ),
      createdAt: now,
      updatedAt: now,
    );

    Widget createTestApp(List<WorkItem> workItems) {
      return ProviderScope(
        overrides: [
          currentWorkspaceProvider
              .overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
          projectsProvider
              .overrideWith(() => _FakeProjectsNotifier([testProject])),
          categoriesProvider
              .overrideWith(() => _FakeCategoriesNotifier([testCategory])),
          tagsProvider.overrideWith(() => _FakeTagsNotifier([])),
          peopleProvider.overrideWith(() => _FakePeopleNotifier([])),
          workItemsProvider
              .overrideWith(() => _FakeWorkItemsNotifier(workItems)),
          unfilteredWorkItemsProvider
              .overrideWith((ref) async => workItems),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: PlannerView()),
        ),
      );
    }

    testWidgets('renders EmptyState when no planned work items exist',
        (tester) async {
      await tester.pumpWidget(createTestApp([]));
      await tester.pumpAndSettle();

      expect(find.text('Nothing planned'), findsOneWidget);
      expect(find.text('Go to Work Items'), findsOneWidget);
    });

    testWidgets('groups items into respective sections in PlannerView',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestApp([itemOverdue, itemDueToday, itemStartingToday]),
      );
      await tester.pumpAndSettle();

      // Section headers are displayed
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Due Today'), findsOneWidget);
      expect(find.text('Starting Today'), findsOneWidget);

      // Tasks appear under sections
      expect(find.text('Late Project Delivery'), findsOneWidget);
      expect(find.text('Urgent Fix Due Today'), findsOneWidget);
      expect(find.text('Kickoff Starting Today'), findsOneWidget);
    });

    testWidgets('toggling section header collapses and expands items',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp([itemOverdue]));
      await tester.pumpAndSettle();

      expect(find.text('Late Project Delivery'), findsOneWidget);

      // Tap section header to collapse
      await tester.tap(find.text('Overdue'));
      await tester.pumpAndSettle();

      expect(find.text('Late Project Delivery'), findsNothing);

      // Tap section header again to expand
      await tester.tap(find.text('Overdue'));
      await tester.pumpAndSettle();

      expect(find.text('Late Project Delivery'), findsOneWidget);
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
}
