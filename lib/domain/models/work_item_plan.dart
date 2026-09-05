import 'package:equatable/equatable.dart';
import 'package:workpulse/domain/models/calendar_date.dart';

enum PlanStatus {
  unplanned, // no dates at all
  scheduled, // planned start is in the future
  startsToday, // planned start is today
  open, // started, or due in the future with no start date
  dueToday,
  overdue,
  completed,
}

class WorkItemPlan extends Equatable {
  final CalendarDate? plannedStart;
  final CalendarDate? due;
  final DateTime? completedAt; // UTC instant

  const WorkItemPlan({
    this.plannedStart,
    this.due,
    this.completedAt,
  });

  const WorkItemPlan.unplanned()
      : plannedStart = null,
        due = null,
        completedAt = null;

  bool get isPlanned => plannedStart != null || due != null;
  bool get isComplete => completedAt != null;

  /// The plan's position in its own lifecycle, as of [today]. Never stored.
  PlanStatus statusOn(CalendarDate today) {
    if (completedAt != null) {
      return PlanStatus.completed;
    }
    if (due != null && due! < today) {
      return PlanStatus.overdue;
    }
    if (due != null && due! == today) {
      return PlanStatus.dueToday;
    }
    if (plannedStart != null && plannedStart! == today) {
      return PlanStatus.startsToday;
    }
    if (plannedStart != null && plannedStart! > today) {
      return PlanStatus.scheduled;
    }
    if (plannedStart != null || due != null) {
      return PlanStatus.open;
    }
    return PlanStatus.unplanned;
  }

  /// Whether the work was delivered after the day it was due. Null when the
  /// item is not complete, or was complete with no due date to be late against.
  bool? get wasLate {
    if (completedAt == null || due == null) return null;
    final completionDate = CalendarDate.fromLocal(completedAt!);
    return completionDate > due!;
  }

  /// Negative when overdue. Null with no due date.
  int? daysUntilDue(CalendarDate today) {
    if (due == null) return null;
    return due!.differenceInDays(today);
  }

  /// A start after its own due date. The form prevents it; this exists
  /// so a hand-edited database renders as an anomaly instead of crashing.
  bool get isInverted =>
      plannedStart != null && due != null && due! < plannedStart!;

  WorkItemPlan copyWith({
    CalendarDate? plannedStart,
    CalendarDate? due,
    DateTime? completedAt,
    bool clearPlannedStart = false,
    bool clearDue = false,
    bool clearCompletedAt = false,
  }) {
    return WorkItemPlan(
      plannedStart:
          clearPlannedStart ? null : (plannedStart ?? this.plannedStart),
      due: clearDue ? null : (due ?? this.due),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  @override
  List<Object?> get props => [plannedStart, due, completedAt];
}
