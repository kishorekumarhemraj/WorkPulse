import 'package:workpulse/domain/models/calendar_date.dart';
import 'package:workpulse/domain/models/reminder_candidate.dart';
import 'package:workpulse/domain/models/reminder_rule.dart';
import 'package:workpulse/domain/models/work_item_model.dart';

/// Pure evaluation service for automated reminders.
///
/// Contains zero platform, Flutter or SQLite dependencies (Rule 8 & Invariant F8).
class ReminderService {
  const ReminderService();

  /// Evaluates the list of [workItems] and returns all eligible [ReminderCandidate]s
  /// that have not yet been recorded in [deliveredKeys].
  ///
  /// [deliveredKeys] format: `"$workItemId:${rule.name}:$occurrenceKey"`.
  List<ReminderCandidate> evaluate({
    required List<WorkItem> workItems,
    required DateTime nowLocal,
    required Set<String> deliveredKeys,
    Set<ReminderRule> enabledRules = const {
      ReminderRule.dueMorning,
      ReminderRule.due1h,
      ReminderRule.overdueDaily,
      ReminderRule.startMorning,
    },
    int dailyDigestHour = 9,
    int dailyDigestMinute = 0,
    Duration dueReminderLeadTime = const Duration(hours: 1),
    bool weekendReminders = false,
    int? quietHoursStartHour,
    int? quietHoursStartMinute,
    int? quietHoursEndHour,
    int? quietHoursEndMinute,
  }) {
    // 1. Weekend check
    final isWeekend = nowLocal.weekday == DateTime.saturday ||
        nowLocal.weekday == DateTime.sunday;
    if (isWeekend && !weekendReminders) {
      return const [];
    }

    // 2. Quiet hours check
    if (quietHoursStartHour != null && quietHoursEndHour != null) {
      final nowMinutes = nowLocal.hour * 60 + nowLocal.minute;
      final startMinutes =
          quietHoursStartHour * 60 + (quietHoursStartMinute ?? 0);
      final endMinutes = quietHoursEndHour * 60 + (quietHoursEndMinute ?? 0);

      bool inQuietHours;
      if (startMinutes <= endMinutes) {
        inQuietHours = nowMinutes >= startMinutes && nowMinutes < endMinutes;
      } else {
        // Overnight quiet hours (e.g. 22:00 -> 08:00)
        inQuietHours = nowMinutes >= startMinutes || nowMinutes < endMinutes;
      }

      if (inQuietHours) {
        return const [];
      }
    }

    final today = CalendarDate.fromLocal(nowLocal);
    final isAfterDigest = (nowLocal.hour > dailyDigestHour) ||
        (nowLocal.hour == dailyDigestHour &&
            nowLocal.minute >= dailyDigestMinute);

    final candidates = <ReminderCandidate>[];

    for (final item in workItems) {
      if (item.isArchived || item.plan.isComplete) continue;

      final plan = item.plan;

      // Rule: startMorning
      if (enabledRules.contains(ReminderRule.startMorning) &&
          plan.plannedStart != null &&
          plan.plannedStart! == today &&
          isAfterDigest) {
        final key = today.toStorageString();
        final ledgerKey = '${item.id}:${ReminderRule.startMorning.name}:$key';
        if (!deliveredKeys.contains(ledgerKey)) {
          candidates.add(
            ReminderCandidate(
              workItemId: item.id,
              workItemName: item.name,
              rule: ReminderRule.startMorning,
              occurrenceKey: key,
              scheduledFor: nowLocal,
              title: 'Starting Today: ${item.name}',
              body: 'Planned to start today.',
            ),
          );
        }
      }

      // Rule: dueMorning
      if (enabledRules.contains(ReminderRule.dueMorning) &&
          plan.due != null &&
          plan.due! == today &&
          isAfterDigest) {
        final key = today.toStorageString();
        final ledgerKey = '${item.id}:${ReminderRule.dueMorning.name}:$key';
        if (!deliveredKeys.contains(ledgerKey)) {
          candidates.add(
            ReminderCandidate(
              workItemId: item.id,
              workItemName: item.name,
              rule: ReminderRule.dueMorning,
              occurrenceKey: key,
              scheduledFor: nowLocal,
              title: 'Due Today: ${item.name}',
              body: 'Due by end of day today.',
            ),
          );
        }
      }

      // Rule: due1h (fires 1 hour before 17:00 or lead time)
      final due1hTriggerHour = (17 - dueReminderLeadTime.inHours).clamp(0, 23);
      if (enabledRules.contains(ReminderRule.due1h) &&
          plan.due != null &&
          plan.due! == today &&
          nowLocal.hour >= due1hTriggerHour) {
        final key = today.toStorageString();
        final ledgerKey = '${item.id}:${ReminderRule.due1h.name}:$key';
        if (!deliveredKeys.contains(ledgerKey)) {
          candidates.add(
            ReminderCandidate(
              workItemId: item.id,
              workItemName: item.name,
              rule: ReminderRule.due1h,
              occurrenceKey: key,
              scheduledFor: nowLocal,
              title: 'Due Soon: ${item.name}',
              body: 'Due today (${item.name}).',
            ),
          );
        }
      }

      // Rule: overdueDaily
      if (enabledRules.contains(ReminderRule.overdueDaily) &&
          plan.due != null &&
          plan.due! < today &&
          isAfterDigest) {
        final key = today.toStorageString();
        final ledgerKey = '${item.id}:${ReminderRule.overdueDaily.name}:$key';
        if (!deliveredKeys.contains(ledgerKey)) {
          final daysLate = today.differenceInDays(plan.due!);
          candidates.add(
            ReminderCandidate(
              workItemId: item.id,
              workItemName: item.name,
              rule: ReminderRule.overdueDaily,
              occurrenceKey: key,
              scheduledFor: nowLocal,
              title: 'Overdue: ${item.name}',
              body:
                  'Overdue by $daysLate ${daysLate == 1 ? 'day' : 'days'}.',
            ),
          );
        }
      }
    }

    return candidates;
  }
}
