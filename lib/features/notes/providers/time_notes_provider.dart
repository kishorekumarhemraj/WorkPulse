import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/time_note_model.dart';
import 'package:workpulse/domain/services/time_notes_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/timesheet/providers/timesheet_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

final timeNotesServiceProvider = Provider<TimeNotesService>((ref) {
  return const TimeNotesService();
});

final timeNotesRangeProvider =
    NotifierProvider<TimeNotesRangeNotifier, DashboardTimeRange>(
  TimeNotesRangeNotifier.new,
);

class TimeNotesRangeNotifier extends Notifier<DashboardTimeRange> {
  @override
  DashboardTimeRange build() => DashboardTimeRange.today;

  void setRange(DashboardTimeRange range) => state = range;
}

/// Single-day date provider for the Time Notes date stepper, mirroring
/// [reportsDateProvider] in Time Log.
final timeNotesDateProvider = NotifierProvider<TimeNotesDateNotifier, DateTime>(
  TimeNotesDateNotifier.new,
);

class TimeNotesDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }

  void previousDay() {
    state = DateTime(state.year, state.month, state.day - 1);
  }

  void nextDay() {
    state = DateTime(state.year, state.month, state.day + 1);
  }

  void goToToday() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, now.day);
  }
}

final timeNotesSearchProvider =
    NotifierProvider<TimeNotesSearchNotifier, String>(
  TimeNotesSearchNotifier.new,
);

class TimeNotesSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

/// Computes the effective DateRange and whether it represents a single day.
final timeNotesDateRangeProvider =
    Provider<({DateRange range, bool isSingleDay})>((ref) {
  final timeRange = ref.watch(timeNotesRangeProvider);
  final selectedDate = ref.watch(timeNotesDateProvider);

  switch (timeRange) {
    case DashboardTimeRange.today:
      final now = DateTime.now();
      final localStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final localEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      return (
        range: DateRange(start: localStart.toUtc(), end: localEnd.toUtc()),
        isSingleDay: true,
      );
    case DashboardTimeRange.thisWeek:
      return (
        range: DashboardTimeRange.thisWeek.toDateRange(),
        isSingleDay: false,
      );
    case DashboardTimeRange.thisMonth:
      return (
        range: DashboardTimeRange.thisMonth.toDateRange(),
        isSingleDay: false,
      );
    case DashboardTimeRange.custom:
      final localStart = DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
      final localEnd = DateTime(selectedDate.year, selectedDate.month,
          selectedDate.day, 23, 59, 59, 999);
      return (
        range: DateRange(
          start: localStart.toUtc(),
          end: localEnd.toUtc(),
        ),
        isSingleDay: true,
      );
  }
});

/// Fetches and groups all notes from sessions within the selected time window.
final timeNotesProvider = FutureProvider<TimeNotesReport>((ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  final exportService = ref.watch(exportServiceProvider);
  final rangeInfo = ref.watch(timeNotesDateRangeProvider);
  final searchQuery = ref.watch(timeNotesSearchProvider);
  final service = ref.watch(timeNotesServiceProvider);
  final codes = ref.watch(timesheetCodeResolverProvider).value ??
      const TimesheetCodeResolver();

  final records = await exportService.getExportRecords(
    workspaceId: workspace.id,
    range: rangeInfo.range,
  );

  return service.buildReport(
    records: records,
    codes: codes,
    searchQuery: searchQuery,
    range: rangeInfo.range,
    isSingleDay: rangeInfo.isSingleDay,
  );
});
