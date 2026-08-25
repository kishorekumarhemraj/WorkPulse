import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/features/notes/models/time_note_entry.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

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

/// Fetches and groups all notes from sessions within the selected time window.
final timeNotesProvider =
    FutureProvider<Map<DateTime, List<TimeNoteEntry>>>((ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  final exportService = ref.watch(exportServiceProvider);
  final timeRange = ref.watch(timeNotesRangeProvider);
  final selectedDate = ref.watch(timeNotesDateProvider);
  final searchQuery = ref.watch(timeNotesSearchProvider).trim().toLowerCase();

  DateRange calculatedRange;
  switch (timeRange) {
    case DashboardTimeRange.today:
      final now = DateTime.now();
      final localStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final localEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      calculatedRange =
          DateRange(start: localStart.toUtc(), end: localEnd.toUtc());
      break;
    case DashboardTimeRange.thisWeek:
      calculatedRange = DashboardTimeRange.thisWeek.toDateRange();
      break;
    case DashboardTimeRange.thisMonth:
      calculatedRange = DashboardTimeRange.thisMonth.toDateRange();
      break;
    case DashboardTimeRange.custom:
      final localStart = DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
      final localEnd = DateTime(selectedDate.year, selectedDate.month,
          selectedDate.day, 23, 59, 59, 999);
      calculatedRange = DateRange(
        start: localStart.toUtc(),
        end: localEnd.toUtc(),
      );
      break;
  }

  final records = await exportService.getExportRecords(
    workspaceId: workspace.id,
    range: calculatedRange,
  );

  final entries = <TimeNoteEntry>[];

  for (final record in records) {
    // Only include entries with meaningful notes on the session or work item
    final sessionNote = record.session.notes?.trim() ?? '';
    final workItemNote = record.workItem.notes?.trim() ?? '';
    final noteContent = sessionNote.isNotEmpty
        ? sessionNote
        : (workItemNote.isNotEmpty ? workItemNote : '');

    if (noteContent.isEmpty) continue;

    final entry = TimeNoteEntry(
      session: record.session,
      workItem: record.workItem,
      project: record.project,
      category: record.category,
      people: record.people,
      tags: record.tags,
      note: noteContent,
      startTime: record.session.startTime,
      endTime: record.session.endTime,
      duration: record.session.duration,
    );

    if (searchQuery.isNotEmpty) {
      final matchesQuery = entry.note.toLowerCase().contains(searchQuery) ||
          entry.workItem.name.toLowerCase().contains(searchQuery) ||
          (entry.project?.name.toLowerCase().contains(searchQuery) ?? false) ||
          (entry.category?.name.toLowerCase().contains(searchQuery) ?? false) ||
          entry.people.any((p) => p.name.toLowerCase().contains(searchQuery)) ||
          entry.tags.any((t) => t.name.toLowerCase().contains(searchQuery));

      if (!matchesQuery) continue;
    }

    entries.add(entry);
  }

  // Sort descending by start time
  entries.sort((a, b) => b.startTime.compareTo(a.startTime));

  // Group by local calendar day (normalized to midnight)
  final grouped = <DateTime, List<TimeNoteEntry>>{};
  for (final entry in entries) {
    final local = entry.startTime.toLocal();
    final dayKey = DateTime(local.year, local.month, local.day);
    grouped.putIfAbsent(dayKey, () => []).add(entry);
  }

  return grouped;
});
