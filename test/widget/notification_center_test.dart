import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/calendar_date.dart';
import 'package:workpulse/domain/models/reminder_rule.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/work_item_plan.dart';
import 'package:workpulse/domain/models/work_item_reminder_record.dart';
import 'package:workpulse/features/reminders/providers/reminders_provider.dart';
import 'package:workpulse/features/reminders/views/notification_center_popover.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';

class _FakeRemindersNotifier extends RemindersNotifier {
  final List<WorkItemReminderRecord> _records;
  _FakeRemindersNotifier(this._records);
  @override
  Future<List<WorkItemReminderRecord>> build() async => _records;
}

class _FakeWorkItemsNotifier extends WorkItemsNotifier {
  final List<WorkItem> _items;
  _FakeWorkItemsNotifier(this._items);
  @override
  Future<List<WorkItem>> build() async => _items;
}

void main() {
  group('NotificationCenterDialog Tests', () {
    final now = DateTime.now().toUtc();
    final today = CalendarDate.fromLocal(DateTime.now());

    final testItem = WorkItem(
      id: 'item-1',
      workspaceId: 'ws-1',
      name: 'Launch Landing Page',
      projectId: 'p1',
      categoryId: 'c1',
      plan: WorkItemPlan(due: today),
      createdAt: now,
      updatedAt: now,
    );

    final testReminder = WorkItemReminderRecord(
      id: 'rem-1',
      workItemId: 'item-1',
      rule: ReminderRule.dueMorning,
      occurrenceKey: today.toStorageString(),
      anchorDate: today,
      deliveredAt: now,
    );

    testWidgets('renders empty state when no notifications exist',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remindersProvider.overrideWith(() => _FakeRemindersNotifier([])),
            workItemsProvider.overrideWith(() => _FakeWorkItemsNotifier([])),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: NotificationCenterDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No notifications'), findsOneWidget);
    });

    testWidgets('renders list of delivered reminders with task name',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remindersProvider
                .overrideWith(() => _FakeRemindersNotifier([testReminder])),
            workItemsProvider
                .overrideWith(() => _FakeWorkItemsNotifier([testItem])),
            unfilteredWorkItemsProvider
                .overrideWith((ref) async => [testItem]),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: NotificationCenterDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Launch Landing Page'), findsOneWidget);
      expect(find.text('DUE TODAY'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('Mark read'), findsOneWidget);
    });
  });
}
