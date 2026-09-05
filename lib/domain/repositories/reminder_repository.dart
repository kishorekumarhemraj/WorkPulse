import 'package:workpulse/domain/models/work_item_reminder_record.dart';

abstract class ReminderRepository {
  Future<void> recordDelivery(WorkItemReminderRecord record);
  Future<List<WorkItemReminderRecord>> getForWorkItem(String workItemId);
  Future<List<WorkItemReminderRecord>> getAll({int? limit});
  Future<Set<String>> getDeliveredKeys();
  Future<void> markRead(String id, DateTime readAt);
  Future<void> markAllRead(DateTime readAt);
  Future<void> snooze(String id, DateTime snoozedUntil);
  Future<void> pruneOld(Duration olderThan);
}
