import 'package:equatable/equatable.dart';
import 'package:workpulse/domain/models/calendar_date.dart';
import 'package:workpulse/domain/models/reminder_rule.dart';

/// Persisted ledger entry for a delivered reminder notification.
class WorkItemReminderRecord extends Equatable {
  final String id;
  final String workItemId;
  final ReminderRule rule;
  final String occurrenceKey;
  final CalendarDate anchorDate;
  final DateTime deliveredAt;
  final DateTime? readAt;
  final DateTime? snoozedUntil;

  const WorkItemReminderRecord({
    required this.id,
    required this.workItemId,
    required this.rule,
    required this.occurrenceKey,
    required this.anchorDate,
    required this.deliveredAt,
    this.readAt,
    this.snoozedUntil,
  });

  bool get isRead => readAt != null;
  bool get isSnoozed =>
      snoozedUntil != null && snoozedUntil!.isAfter(DateTime.now().toUtc());

  WorkItemReminderRecord copyWith({
    String? id,
    String? workItemId,
    ReminderRule? rule,
    String? occurrenceKey,
    CalendarDate? anchorDate,
    DateTime? deliveredAt,
    DateTime? readAt,
    bool clearReadAt = false,
    DateTime? snoozedUntil,
    bool clearSnoozedUntil = false,
  }) {
    return WorkItemReminderRecord(
      id: id ?? this.id,
      workItemId: workItemId ?? this.workItemId,
      rule: rule ?? this.rule,
      occurrenceKey: occurrenceKey ?? this.occurrenceKey,
      anchorDate: anchorDate ?? this.anchorDate,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      snoozedUntil:
          clearSnoozedUntil ? null : (snoozedUntil ?? this.snoozedUntil),
    );
  }

  @override
  List<Object?> get props => [
        id,
        workItemId,
        rule,
        occurrenceKey,
        anchorDate,
        deliveredAt,
        readAt,
        snoozedUntil,
      ];
}
