import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/models/calendar_date.dart';
import 'package:workpulse/domain/models/reminder_rule.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/work_item_plan.dart';
import 'package:workpulse/domain/services/reminder_service.dart';

void main() {
  group('ReminderService Unit Tests', () {
    const service = ReminderService();
    const today = CalendarDate(2026, 9, 3); // Thursday
    final time0900 = DateTime(2026, 9, 3, 9, 0);
    final time0859 = DateTime(2026, 9, 3, 8, 59);
    final time1630 = DateTime(2026, 9, 3, 16, 30);

    final itemDueToday = WorkItem(
      id: 'item-due-today',
      workspaceId: 'ws-1',
      name: 'Due today item',
      projectId: 'p1',
      categoryId: 'c1',
      plan: const WorkItemPlan(due: today),
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );

    final itemStartsToday = WorkItem(
      id: 'item-starts-today',
      workspaceId: 'ws-1',
      name: 'Starts today item',
      projectId: 'p1',
      categoryId: 'c1',
      plan: const WorkItemPlan(plannedStart: today),
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );

    final itemOverdue = WorkItem(
      id: 'item-overdue',
      workspaceId: 'ws-1',
      name: 'Overdue item',
      projectId: 'p1',
      categoryId: 'c1',
      plan: WorkItemPlan(due: today.addDays(-2)),
      createdAt: DateTime(2026, 8, 20),
      updatedAt: DateTime(2026, 8, 20),
    );

    final itemCompleted = WorkItem(
      id: 'item-completed',
      workspaceId: 'ws-1',
      name: 'Completed item',
      projectId: 'p1',
      categoryId: 'c1',
      plan: WorkItemPlan(
        due: today,
        completedAt: DateTime(2026, 9, 2),
      ),
      createdAt: DateTime(2026, 8, 20),
      updatedAt: DateTime(2026, 9, 2),
    );

    final itemArchived = WorkItem(
      id: 'item-archived',
      workspaceId: 'ws-1',
      name: 'Archived item',
      projectId: 'p1',
      categoryId: 'c1',
      archivedAt: DateTime(2026, 9, 1),
      plan: const WorkItemPlan(due: today),
      createdAt: DateTime(2026, 8, 20),
      updatedAt: DateTime(2026, 9, 1),
    );

    test('does not fire morning reminders before daily digest time', () {
      final candidates = service.evaluate(
        workItems: [itemDueToday, itemStartsToday, itemOverdue],
        nowLocal: time0859,
        deliveredKeys: {},
        dailyDigestHour: 9,
        dailyDigestMinute: 0,
      );

      expect(candidates, isEmpty);
    });

    test('fires morning reminders at or after daily digest time', () {
      final candidates = service.evaluate(
        workItems: [itemDueToday, itemStartsToday, itemOverdue],
        nowLocal: time0900,
        deliveredKeys: {},
        dailyDigestHour: 9,
        dailyDigestMinute: 0,
      );

      expect(candidates, hasLength(3));
      expect(
        candidates.map((c) => c.rule),
        containsAll([
          ReminderRule.dueMorning,
          ReminderRule.startMorning,
          ReminderRule.overdueDaily,
        ]),
      );
    });

    test('deduplicates reminders against deliveredKeys ledger', () {
      final key = today.toStorageString();
      final delivered = {
        'item-due-today:dueMorning:$key',
      };

      final candidates = service.evaluate(
        workItems: [itemDueToday],
        nowLocal: time0900,
        deliveredKeys: delivered,
      );

      expect(candidates, isEmpty);
    });

    test('fires due1h in the afternoon before workday end', () {
      final candidates = service.evaluate(
        workItems: [itemDueToday],
        nowLocal: time1630,
        deliveredKeys: {'item-due-today:dueMorning:${today.toStorageString()}'},
      );

      expect(candidates, hasLength(1));
      expect(candidates.first.rule, ReminderRule.due1h);
    });

    test('skips completed and archived items', () {
      final candidates = service.evaluate(
        workItems: [itemCompleted, itemArchived],
        nowLocal: time0900,
        deliveredKeys: {},
      );

      expect(candidates, isEmpty);
    });

    test('suppresses reminders on weekends when weekendReminders is false', () {
      final saturdayTime = DateTime(2026, 9, 5, 10, 0); // Saturday
      final candidates = service.evaluate(
        workItems: [itemOverdue],
        nowLocal: saturdayTime,
        deliveredKeys: {},
        weekendReminders: false,
      );

      expect(candidates, isEmpty);
    });

    test('allows reminders on weekends when weekendReminders is true', () {
      final saturdayTime = DateTime(2026, 9, 5, 10, 0); // Saturday
      final candidates = service.evaluate(
        workItems: [itemOverdue],
        nowLocal: saturdayTime,
        deliveredKeys: {},
        weekendReminders: true,
      );

      expect(candidates, hasLength(1));
      expect(candidates.first.rule, ReminderRule.overdueDaily);
    });

    test('suppresses reminders during quiet hours', () {
      final eveningTime = DateTime(2026, 9, 3, 23, 0);
      final candidates = service.evaluate(
        workItems: [itemOverdue],
        nowLocal: eveningTime,
        deliveredKeys: {},
        quietHoursStartHour: 22,
        quietHoursEndHour: 8,
      );

      expect(candidates, isEmpty);
    });
  });
}
