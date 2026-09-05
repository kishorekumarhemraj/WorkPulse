import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/models/calendar_date.dart';
import 'package:workpulse/domain/models/work_item_plan.dart';

void main() {
  group('WorkItemPlan & PlanStatus', () {
    const today = CalendarDate(2026, 9, 3);
    const yesterday = CalendarDate(2026, 9, 2);
    const tomorrow = CalendarDate(2026, 9, 4);
    const nextWeek = CalendarDate(2026, 9, 10);

    test('unplanned defaults', () {
      const plan = WorkItemPlan.unplanned();
      expect(plan.isPlanned, isFalse);
      expect(plan.isComplete, isFalse);
      expect(plan.statusOn(today), PlanStatus.unplanned);
      expect(plan.daysUntilDue(today), isNull);
      expect(plan.wasLate, isNull);
      expect(plan.isInverted, isFalse);
    });

    test('status precedence: completed beats all', () {
      final completedOverdue = WorkItemPlan(
        due: yesterday,
        completedAt: DateTime.utc(2026, 9, 2, 10, 0),
      );
      expect(completedOverdue.statusOn(today), PlanStatus.completed);
      expect(completedOverdue.isComplete, isTrue);
    });

    test('status precedence: overdue beats dueToday/startsToday', () {
      const plan = WorkItemPlan(
        plannedStart: today,
        due: yesterday,
      );
      expect(plan.statusOn(today), PlanStatus.overdue);
    });

    test('status precedence: dueToday beats startsToday', () {
      const plan = WorkItemPlan(
        plannedStart: today,
        due: today,
      );
      expect(plan.statusOn(today), PlanStatus.dueToday);
    });

    test('status precedence: startsToday when start is today and due is later',
        () {
      const plan = WorkItemPlan(
        plannedStart: today,
        due: tomorrow,
      );
      expect(plan.statusOn(today), PlanStatus.startsToday);
    });

    test('status precedence: scheduled when plannedStart is in the future', () {
      const plan = WorkItemPlan(
        plannedStart: tomorrow,
        due: nextWeek,
      );
      expect(plan.statusOn(today), PlanStatus.scheduled);
    });

    test('status precedence: open when due is future without start date', () {
      const plan = WorkItemPlan(
        due: tomorrow,
      );
      expect(plan.statusOn(today), PlanStatus.open);
    });

    test('status precedence: open when started in the past and due in future',
        () {
      const plan = WorkItemPlan(
        plannedStart: yesterday,
        due: tomorrow,
      );
      expect(plan.statusOn(today), PlanStatus.open);
    });

    test('status precedence: open when started in the past without due date',
        () {
      const plan = WorkItemPlan(
        plannedStart: yesterday,
      );
      expect(plan.statusOn(today), PlanStatus.open);
      expect(plan.due, isNull);
    });

    test('wasLate calculation', () {
      // Completed on time (same day as due)
      final onTime = WorkItemPlan(
        due: const CalendarDate(2026, 9, 3),
        completedAt: DateTime(2026, 9, 3, 17, 0),
      );
      expect(onTime.wasLate, isFalse);

      // Completed late (day after due)
      final late = WorkItemPlan(
        due: const CalendarDate(2026, 9, 3),
        completedAt: DateTime(2026, 9, 4, 9, 0),
      );
      expect(late.wasLate, isTrue);

      // Completed early
      final early = WorkItemPlan(
        due: const CalendarDate(2026, 9, 3),
        completedAt: DateTime(2026, 9, 2, 18, 0),
      );
      expect(early.wasLate, isFalse);

      // Completed with no due date
      final noDue = WorkItemPlan(
        completedAt: DateTime(2026, 9, 3, 12, 0),
      );
      expect(noDue.wasLate, isNull);
    });

    test('daysUntilDue returns positive, zero, negative or null', () {
      expect(const WorkItemPlan(due: tomorrow).daysUntilDue(today), 1);
      expect(const WorkItemPlan(due: today).daysUntilDue(today), 0);
      expect(const WorkItemPlan(due: yesterday).daysUntilDue(today), -1);
      expect(const WorkItemPlan.unplanned().daysUntilDue(today), isNull);
    });

    test('isInverted detects planned start after due date', () {
      const normal = WorkItemPlan(plannedStart: today, due: tomorrow);
      expect(normal.isInverted, isFalse);

      const inverted = WorkItemPlan(plannedStart: tomorrow, due: today);
      expect(inverted.isInverted, isTrue);

      const sameDay = WorkItemPlan(plannedStart: today, due: today);
      expect(sameDay.isInverted, isFalse);
    });
  });
}
