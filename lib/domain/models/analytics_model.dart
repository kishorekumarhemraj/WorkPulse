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
    final now = referenceTime ?? DateTime.now().toUtc();

    switch (this) {
      case DashboardTimeRange.today:
        final start = DateTime.utc(now.year, now.month, now.day);
        final end = DateTime.utc(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateRange(start: start, end: end);

      case DashboardTimeRange.thisWeek:
        // Monday as first day of week
        final daysToSubtract = (now.weekday - DateTime.monday) % 7;
        final startOfWeek =
            DateTime.utc(now.year, now.month, now.day - daysToSubtract);
        final endOfWeek = DateTime.utc(
            now.year, now.month, now.day - daysToSubtract + 6, 23, 59, 59, 999);
        return DateRange(start: startOfWeek, end: endOfWeek);

      case DashboardTimeRange.thisMonth:
        final startOfMonth = DateTime.utc(now.year, now.month, 1);
        final nextMonth = now.month == 12
            ? DateTime.utc(now.year + 1, 1, 1)
            : DateTime.utc(now.year, now.month + 1, 1);
        final endOfMonth = nextMonth.subtract(const Duration(milliseconds: 1));
        return DateRange(start: startOfMonth, end: endOfMonth);

      case DashboardTimeRange.custom:
        return customRange ??
            DateRange(
              start: DateTime.utc(now.year, now.month, now.day),
              end: DateTime.utc(now.year, now.month, now.day, 23, 59, 59, 999),
            );
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
      ];
}
