import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/platform/desktop_notification_service.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/calendar_date.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/work_item_plan.dart';
import 'package:workpulse/domain/models/work_item_reminder_record.dart';
import 'package:workpulse/domain/repositories/reminder_repository.dart';
import 'package:workpulse/features/reminders/providers/reminder_scheduler_provider.dart';
import 'package:workpulse/features/settings/providers/app_settings_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';

class _FakeReminderRepository implements ReminderRepository {
  final List<WorkItemReminderRecord> records = [];

  @override
  Future<void> recordDelivery(WorkItemReminderRecord record) async {
    records.add(record);
  }

  @override
  Future<List<WorkItemReminderRecord>> getAll({int? limit}) async => records;

  @override
  Future<Set<String>> getDeliveredKeys() async {
    return records
        .map((r) => '${r.workItemId}:${r.rule.name}:${r.occurrenceKey}')
        .toSet();
  }

  @override
  Future<List<WorkItemReminderRecord>> getForWorkItem(String workItemId) async {
    return records.where((r) => r.workItemId == workItemId).toList();
  }

  @override
  Future<void> markAllRead(DateTime readAt) async {
    for (var i = 0; i < records.length; i++) {
      records[i] = records[i].copyWith(readAt: readAt);
    }
  }

  @override
  Future<void> markRead(String id, DateTime readAt) async {
    final idx = records.indexWhere((r) => r.id == id);
    if (idx != -1) {
      records[idx] = records[idx].copyWith(readAt: readAt);
    }
  }

  @override
  Future<void> pruneOld(Duration olderThan) async {}

  @override
  Future<void> snooze(String id, DateTime snoozedUntil) async {
    final idx = records.indexWhere((r) => r.id == id);
    if (idx != -1) {
      records[idx] = records[idx].copyWith(snoozedUntil: snoozedUntil);
    }
  }
}

class _FakeWorkItemsNotifier extends WorkItemsNotifier {
  final List<WorkItem> _items;
  _FakeWorkItemsNotifier(this._items);
  @override
  Future<List<WorkItem>> build() async => _items;
}

class _FakeAppSettingsNotifier extends AppSettingsNotifier {
  final AppSettings _settings;
  _FakeAppSettingsNotifier([AppSettings? settings])
      : _settings = settings ?? AppSettings.defaults();
  @override
  Future<AppSettings> build() async => _settings;
}

void main() {
  group('ReminderScheduler Tests', () {
    final fixedTime = DateTime(2026, 9, 3, 10, 0); // Thursday 10:00 AM
    const today = CalendarDate(2026, 9, 3);
    final testItem = WorkItem(
      id: 'item-101',
      workspaceId: 'ws-1',
      name: 'Critical Task Due Today',
      projectId: 'proj-1',
      categoryId: 'cat-1',
      plan: const WorkItemPlan(due: today),
      createdAt: fixedTime,
      updatedAt: fixedTime,
    );

    test('evaluates reminders and writes ledger and dispatches notification',
        () async {
      final fakeRepo = _FakeReminderRepository();
      final fakeNotificationService = NoOpDesktopNotificationService();

      final container = ProviderContainer(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(fakeRepo),
          desktopNotificationServiceProvider
              .overrideWithValue(fakeNotificationService),
          appSettingsProvider
              .overrideWith(() => _FakeAppSettingsNotifier(AppSettings.defaults())),
          workItemsProvider.overrideWith(() => _FakeWorkItemsNotifier([testItem])),
          reminderSchedulerProvider.overrideWith((ref) {
            final scheduler =
                ReminderScheduler(ref, nowProvider: () => fixedTime);
            ref.onDispose(scheduler.dispose);
            return scheduler;
          }),
        ],
      );
      addTearDown(container.dispose);

      final scheduler = container.read(reminderSchedulerProvider);
      await scheduler.checkReminders();

      // Check candidate was written and notification dispatched
      final deliveredKeys = await fakeRepo.getDeliveredKeys();
      expect(fakeRepo.records.length, greaterThanOrEqualTo(1));
      expect(fakeNotificationService.shownNotifications.length,
          greaterThanOrEqualTo(1));
      expect(
        deliveredKeys,
        contains('item-101:dueMorning:${today.toStorageString()}'),
      );
    });
  });
}
