import 'package:flutter/material.dart';
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

final timeNotesCustomRangeProvider =
    NotifierProvider<TimeNotesCustomRangeNotifier, DateTimeRange?>(
  TimeNotesCustomRangeNotifier.new,
);

class TimeNotesCustomRangeNotifier extends Notifier<DateTimeRange?> {
  @override
  DateTimeRange? build() => null;

  void setCustomRange(DateTimeRange? range) => state = range;
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
  final customRange = ref.watch(timeNotesCustomRangeProvider);
  final searchQuery = ref.watch(timeNotesSearchProvider).trim().toLowerCase();

  final domainCustomRange = customRange != null
      ? DateRange(
          start: customRange.start.toUtc(),
          end: customRange.end.toUtc(),
        )
      : null;
  final calculatedRange = timeRange.toDateRange(customRange: domainCustomRange);

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
