import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/core/platform/desktop_notification_service.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/calendar_date.dart';
import 'package:workpulse/domain/models/work_item_reminder_record.dart';
import 'package:workpulse/domain/services/reminder_service.dart';
import 'package:workpulse/features/reminders/providers/reminders_provider.dart';
import 'package:workpulse/features/settings/providers/app_settings_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';

final desktopNotificationServiceProvider =
    Provider<DesktopNotificationService>((ref) {
  final service = DesktopNotificationServiceImpl();
  service.initialize();
  return service;
});

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final scheduler = ReminderScheduler(ref);
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

class ReminderScheduler {
  final Ref _ref;
  final ReminderService _reminderService = const ReminderService();
  final Uuid _uuid = const Uuid();
  final DateTime Function() _now;
  Timer? _timer;
  bool _isChecking = false;
  bool _isDisposed = false;

  ReminderScheduler(this._ref, {DateTime Function()? nowProvider})
      : _now = nowProvider ?? DateTime.now {
    _startPeriodicCheck();
  }

  void _startPeriodicCheck() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      checkReminders();
    });
  }

  Future<void> checkReminders() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final workItems = await _ref.read(unfilteredWorkItemsProvider.future);
      final settings = await _ref.read(appSettingsProvider.future);
      final repo = _ref.read(reminderRepositoryProvider);
      final notificationService = _ref.read(desktopNotificationServiceProvider);

      final deliveredKeys = await repo.getDeliveredKeys();
      if (_isDisposed) return;
      final nowLocal = _now();

      final candidates = _reminderService.evaluate(
        workItems: workItems,
        nowLocal: nowLocal,
        deliveredKeys: deliveredKeys,
        enabledRules: settings.enabledReminderRules,
        dailyDigestHour: settings.dailyDigestTime.hour,
        dailyDigestMinute: settings.dailyDigestTime.minute,
        dueReminderLeadTime: settings.dueReminderLeadTime,
        weekendReminders: settings.weekendReminders,
        quietHoursStartHour: settings.quietHoursStart?.hour,
        quietHoursStartMinute: settings.quietHoursStart?.minute,
        quietHoursEndHour: settings.quietHoursEnd?.hour,
        quietHoursEndMinute: settings.quietHoursEnd?.minute,
      );

      if (candidates.isEmpty || _isDisposed) return;

      for (final candidate in candidates) {
        if (_isDisposed) return;
        final record = WorkItemReminderRecord(
          id: _uuid.v4(),
          workItemId: candidate.workItemId,
          rule: candidate.rule,
          occurrenceKey: candidate.occurrenceKey,
          anchorDate: CalendarDate.fromLocal(candidate.scheduledFor),
          deliveredAt: DateTime.now().toUtc(),
        );

        await repo.recordDelivery(record);
      }

      if (_isDisposed) return;

      // Grouped notification: 1 candidate speaks for itself, >1 collapsed into count
      if (candidates.length == 1) {
        final first = candidates.first;
        await notificationService.showNotification(
          id: first.workItemId.hashCode ^ first.rule.hashCode,
          title: first.title,
          body: first.body,
          payload: first.workItemId,
        );
      } else if (candidates.length > 1) {
        final overdueCount = candidates
            .where((c) => c.rule == ReminderRule.overdueDaily)
            .length;
        final dueTodayCount = candidates
            .where((c) =>
                c.rule == ReminderRule.dueMorning ||
                c.rule == ReminderRule.due1h)
            .length;

        final parts = <String>[];
        if (overdueCount > 0) parts.add('$overdueCount overdue');
        if (dueTodayCount > 0) parts.add('$dueTodayCount due today');
        final remainder = candidates.length - overdueCount - dueTodayCount;
        if (remainder > 0) parts.add('$remainder upcoming');

        await notificationService.showNotification(
          id: nowLocal.millisecondsSinceEpoch ~/ 1000,
          title: '${candidates.length} work items need attention',
          body: parts.join(' · '),
          payload: 'planner',
        );
      }

      if (!_isDisposed) {
        _ref.invalidate(remindersProvider);
      }
    } catch (e) {
      // Non-fatal logging for reminders evaluation
    } finally {
      _isChecking = false;
    }
  }

  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
