import 'package:equatable/equatable.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/date_range.dart';

enum DashboardTimeRange {
  today('Today'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  custom('Custom');

  final String label;
  const DashboardTimeRange(this.label);

  DateRange toDateRange({DateRange? customRange, DateTime? referenceTime}) {
    final now = (referenceTime ?? DateTime.now()).toLocal();

    switch (this) {
      case DashboardTimeRange.today:
        final localStart = DateTime(now.year, now.month, now.day);
        final localEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateRange(start: localStart.toUtc(), end: localEnd.toUtc());

      case DashboardTimeRange.thisWeek:
        // Sunday as first day of week in user's local time
        final daysToSubtract = now.weekday % 7;
        final localStartOfWeek =
            DateTime(now.year, now.month, now.day - daysToSubtract);
        final localEndOfWeek = DateTime(
            now.year, now.month, now.day - daysToSubtract + 6, 23, 59, 59, 999);
        return DateRange(
            start: localStartOfWeek.toUtc(), end: localEndOfWeek.toUtc());

      case DashboardTimeRange.thisMonth:
        final localStartOfMonth = DateTime(now.year, now.month, 1);
        final localNextMonth = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        final localEndOfMonth =
            localNextMonth.subtract(const Duration(milliseconds: 1));
        return DateRange(
            start: localStartOfMonth.toUtc(), end: localEndOfMonth.toUtc());

      case DashboardTimeRange.custom:
        if (customRange != null) return customRange;
        final localStart = DateTime(now.year, now.month, now.day);
        final localEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateRange(start: localStart.toUtc(), end: localEnd.toUtc());
    }
  }
}

class AnalyticsSummary extends Equatable {
  final Duration totalTrackedDuration;
  final Duration totalActiveDuration;
  final Duration totalIdleDuration;
  final int sessionCount;
  final int taskCount;

  const AnalyticsSummary({
    this.totalTrackedDuration = Duration.zero,
    this.totalActiveDuration = Duration.zero,
    this.totalIdleDuration = Duration.zero,
    this.sessionCount = 0,
    this.taskCount = 0,
  });

  @override
  List<Object?> get props => [
        totalTrackedDuration,
        totalActiveDuration,
        totalIdleDuration,
        sessionCount,
        taskCount,
      ];
}

class BreakdownItem extends Equatable {
  final String id;
  final String name;
  final String? colorHex;
  final String? iconName;
  final Duration duration;
  final double percentage; // 0.0 to 100.0
  final int sessionCount;

  const BreakdownItem({
    required this.id,
    required this.name,
    this.colorHex,
    this.iconName,
    required this.duration,
    required this.percentage,
    required this.sessionCount,
  });

  @override
  List<Object?> get props =>
      [id, name, colorHex, iconName, duration, percentage, sessionCount];
}

class DailyActivityItem extends Equatable {
  final DateTime date;
  final Duration activeDuration;
  final Duration idleDuration;
  final int sessionCount;

  const DailyActivityItem({
    required this.date,
    required this.activeDuration,
    required this.idleDuration,
    required this.sessionCount,
  });

  Duration get totalDuration => activeDuration + idleDuration;

  @override
  List<Object?> get props => [date, activeDuration, idleDuration, sessionCount];
}

class HourlyActivityItem extends Equatable {
  final int hour; // 0..23 local hour
  final Duration activeDuration;
  final Duration idleDuration;
  final int sessionCount;

  const HourlyActivityItem({
    required this.hour,
    required this.activeDuration,
    required this.idleDuration,
    required this.sessionCount,
  });

  Duration get totalDuration => activeDuration + idleDuration;

  @override
  List<Object?> get props => [hour, activeDuration, idleDuration, sessionCount];
}

class AttributeBreakdownGroup extends Equatable {
  final AttributeDefinition definition;
  final List<BreakdownItem> items;

  const AttributeBreakdownGroup({
    required this.definition,
    required this.items,
  });

  @override
  List<Object?> get props => [definition, items];
}

class DashboardData extends Equatable {
  final DateRange range;
  final AnalyticsSummary summary;
  final List<BreakdownItem> projectBreakdown;
  final List<BreakdownItem> categoryBreakdown;
  final List<BreakdownItem> workItemBreakdown;
  final List<BreakdownItem> tagBreakdown;
  final List<BreakdownItem> personBreakdown;
  final List<AttributeBreakdownGroup> attributeBreakdowns;
  final List<DailyActivityItem> dailyActivity;
  final List<HourlyActivityItem> hourlyActivity;

  const DashboardData({
    required this.range,
    required this.summary,
    this.projectBreakdown = const [],
    this.categoryBreakdown = const [],
    this.workItemBreakdown = const [],
    this.tagBreakdown = const [],
    this.personBreakdown = const [],
    this.attributeBreakdowns = const [],
    this.dailyActivity = const [],
    this.hourlyActivity = const [],
  });

  @override
  List<Object?> get props => [
        range,
        summary,
        projectBreakdown,
        categoryBreakdown,
        workItemBreakdown,
        tagBreakdown,
        personBreakdown,
        attributeBreakdowns,
        dailyActivity,
        hourlyActivity,
      ];
}
