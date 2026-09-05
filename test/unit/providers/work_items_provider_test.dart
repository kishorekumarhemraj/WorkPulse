import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/models/calendar_date.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/work_item_plan.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';

void main() {
  group('WorkItemFilter & PlanFilter & WorkItemSort', () {
    final now = DateTime.now();
    final today = CalendarDate.fromLocal(now);

    final itemUnplanned = WorkItem(
      id: 'item-unplanned',
      workspaceId: 'ws-1',
      name: 'Unplanned task',
      projectId: 'p1',
      categoryId: 'c1',
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now,
    );

    final itemOverdue = WorkItem(
      id: 'item-overdue',
      workspaceId: 'ws-1',
      name: 'Overdue task',
      projectId: 'p1',
      categoryId: 'c1',
      plan: WorkItemPlan(due: today.addDays(-2)),
      createdAt: now.subtract(const Duration(days: 4)),
      updatedAt: now,
    );

    final itemDueToday = WorkItem(
      id: 'item-due-today',
      workspaceId: 'ws-1',
      name: 'Due today task',
      projectId: 'p1',
      categoryId: 'c1',
      plan: WorkItemPlan(due: today),
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now,
    );

    final itemDueTomorrow = WorkItem(
      id: 'item-due-tomorrow',
      workspaceId: 'ws-1',
      name: 'Due tomorrow task',
      projectId: 'p1',
      categoryId: 'c1',
      plan: WorkItemPlan(due: today.addDays(1)),
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now,
    );

    final itemScheduled = WorkItem(
      id: 'item-scheduled',
      workspaceId: 'ws-1',
      name: 'Scheduled task',
      projectId: 'p1',
      categoryId: 'c1',
      plan: WorkItemPlan(plannedStart: today.addDays(3)),
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now,
    );

    final itemCompleted = WorkItem(
      id: 'item-completed',
      workspaceId: 'ws-1',
      name: 'Completed task',
      projectId: 'p1',
      categoryId: 'c1',
      plan: WorkItemPlan(
        due: today.addDays(-1),
        completedAt: now.subtract(const Duration(hours: 2)),
      ),
      createdAt: now.subtract(const Duration(days: 6)),
      updatedAt: now,
    );

    final allItems = [
      itemUnplanned,
      itemOverdue,
      itemDueToday,
      itemDueTomorrow,
      itemScheduled,
      itemCompleted,
    ];

    test('PlanFilter.overdue matches only uncompleted overdue items', () {
      final filter = const WorkItemFilter(planFilter: PlanFilter.overdue);
      final filtered = filter.filter(allItems, today: today);
      expect(filtered.map((i) => i.id), [itemOverdue.id]);
    });

    test('PlanFilter.dueToday matches uncompleted tasks due today', () {
      final filter = const WorkItemFilter(planFilter: PlanFilter.dueToday);
      final filtered = filter.filter(allItems, today: today);
      expect(filtered.map((i) => i.id), [itemDueToday.id]);
    });

    test('PlanFilter.unplanned matches items without dates or completion', () {
      final filter = const WorkItemFilter(planFilter: PlanFilter.unplanned);
      final filtered = filter.filter(allItems, today: today);
      expect(filtered.map((i) => i.id), [itemUnplanned.id]);
    });

    test('PlanFilter.completed matches completed items', () {
      final filter = const WorkItemFilter(planFilter: PlanFilter.completed);
      final filtered = filter.filter(allItems, today: today);
      expect(filtered.map((i) => i.id), [itemCompleted.id]);
    });

    test('WorkItemSort.dueDate sorts items by due date ascending, with nulls last', () {
      final filter = const WorkItemFilter(sort: WorkItemSort.dueDate);
      final filtered = filter.filter(allItems, today: today);
      expect(filtered.map((i) => i.id), [
        itemOverdue.id,
        itemCompleted.id,
        itemDueToday.id,
        itemDueTomorrow.id,
        itemUnplanned.id,
        itemScheduled.id,
      ]);
    });

    test('WorkItemSort.name sorts alphabetically by name', () {
      final filter = const WorkItemFilter(sort: WorkItemSort.name);
      final filtered = filter.filter(allItems, today: today);
      expect(
        filtered.map((i) => i.name),
        [
          'Completed task',
          'Due today task',
          'Due tomorrow task',
          'Overdue task',
          'Scheduled task',
          'Unplanned task',
        ],
      );
    });
  });
}
