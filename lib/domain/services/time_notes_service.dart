import 'package:flutter/foundation.dart' hide Category;
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/time_note_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/features/reports/widgets/session_metadata.dart';

/// Pure domain service that transforms session export records into structured,
/// narrative daily time notes reports.
class TimeNotesService {
  const TimeNotesService();

  TimeNotesReport buildReport({
    required List<SessionExportRecord> records,
    required TimesheetCodeResolver codes,
    String searchQuery = '',
    required DateRange range,
    required bool isSingleDay,
  }) {
    final query = searchQuery.trim().toLowerCase();

    // 1. Group records by local calendar day (normalized to midnight)
    final recordsByDay = <DateTime, List<SessionExportRecord>>{};
    for (final r in records) {
      final local = r.session.startTime.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      recordsByDay.putIfAbsent(day, () => []).add(r);
    }

    final dayKeys = recordsByDay.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // newest day first

    final dayGroups = <NotesDayGroup>[];
    var globalUnnotedSessions = 0;

    for (final day in dayKeys) {
      final dayRecords = recordsByDay[day]!;

      // Group by work item id preserving chronological arrival
      final dayTasks = <String, List<SessionExportRecord>>{};
      for (final r in dayRecords) {
        dayTasks.putIfAbsent(r.workItem.id, () => []).add(r);
      }

      final taskGroups = <TaskNoteGroup>[];

      for (final taskRecords in dayTasks.values) {
        // Sort task sessions ascending by start time for forward narrative
        taskRecords
            .sort((a, b) => a.session.startTime.compareTo(b.session.startTime));

        final firstRecord = taskRecords.first;
        final workItem = firstRecord.workItem;
        final project = firstRecord.project;

        final totalTaskDuration = taskRecords.fold<Duration>(
          Duration.zero,
          (sum, r) => sum + r.netActiveDuration,
        );

        final notedSessionRecords = taskRecords
            .where((r) => (r.session.notes ?? '').trim().isNotEmpty)
            .toList();

        final entries = <TimeNoteEntry>[];

        if (notedSessionRecords.isNotEmpty) {
          for (final r in notedSessionRecords) {
            entries.add(
              TimeNoteEntry(
                record: r,
                note: r.session.notes!.trim(),
                source: TimeNoteSource.session,
                timestamp: r.session.startTime,
                duration: r.netActiveDuration,
              ),
            );
          }
          final unnotedCount = taskRecords.length - notedSessionRecords.length;
          globalUnnotedSessions += unnotedCount;
        } else if ((workItem.notes ?? '').trim().isNotEmpty) {
          // Fallback note from work item
          entries.add(
            TimeNoteEntry(
              record: taskRecords.last,
              note: workItem.notes!.trim(),
              source: TimeNoteSource.taskFallback,
              timestamp: taskRecords.first.session.startTime,
              duration: totalTaskDuration,
            ),
          );
        } else {
          // Entirely unnoted task
          globalUnnotedSessions += taskRecords.length;
        }

        if (entries.isEmpty) {
          continue;
        }

        // Determine metadata promotion
        final promotedFields = <SessionMetadataField>{
          SessionMetadataField.project,
        };

        // Category promotion: unanimous category across all task sessions on this day
        final firstCatId = firstRecord.category?.id;
        final isCategoryUnanimous =
            taskRecords.every((r) => r.category?.id == firstCatId);
        Category? promotedCategory;
        if (isCategoryUnanimous) {
          promotedCategory = firstRecord.category;
          promotedFields.add(SessionMetadataField.category);
        }

        // Classification promotion: unanimous classification
        final firstClass = firstRecord.classification;
        final isClassificationUnanimous =
            taskRecords.every((r) => r.classification == firstClass);
        FinancialClassification promotedClassification =
            FinancialClassification.none;
        if (isClassificationUnanimous) {
          promotedClassification = firstClass;
          promotedFields.add(SessionMetadataField.classification);
        }

        // Timesheet Code promotion: unanimous resolved code
        final firstCode = codes.resolveFor(
          project: firstRecord.project,
          attributeOptionIds: firstRecord.attributeOptionIds,
        );
        final isCodeUnanimous = taskRecords.every((r) {
          final res = codes.resolveFor(
            project: r.project,
            attributeOptionIds: r.attributeOptionIds,
          );
          return res.code == firstCode.code && res.source == firstCode.source;
        });
        TimesheetCodeResolution? promotedCode;
        if (isCodeUnanimous) {
          promotedCode = firstCode;
          promotedFields.add(SessionMetadataField.timesheetCode);
        }

        // Tags promotion: unanimous tag set
        final firstTagIds = firstRecord.tags.map((t) => t.id).toSet();
        final isTagsUnanimous = taskRecords.every((r) {
          final rTagIds = r.tags.map((t) => t.id).toSet();
          return setEquals(firstTagIds, rTagIds);
        });
        List<Tag> promotedTags = const [];
        if (isTagsUnanimous) {
          promotedTags = firstRecord.tags;
          promotedFields.add(SessionMetadataField.tags);
        }

        // People promotion: unanimous people set
        final firstPeopleIds = firstRecord.people.map((p) => p.id).toSet();
        final isPeopleUnanimous = taskRecords.every((r) {
          final rPeopleIds = r.people.map((p) => p.id).toSet();
          return setEquals(firstPeopleIds, rPeopleIds);
        });
        List<Person> promotedPeople = const [];
        if (isPeopleUnanimous) {
          promotedPeople = firstRecord.people;
          promotedFields.add(SessionMetadataField.people);
        }

        // Search filtering
        List<TimeNoteEntry> filteredEntries = entries;
        if (query.isNotEmpty) {
          final taskNameMatches = workItem.name.toLowerCase().contains(query);
          final projectNameMatches =
              project?.name.toLowerCase().contains(query) ?? false;
          final categoryNameMatches =
              (promotedCategory?.name.toLowerCase().contains(query) ?? false) ||
                  taskRecords.any((r) =>
                      r.category?.name.toLowerCase().contains(query) ?? false);
          final tagsMatch = taskRecords.any(
              (r) => r.tags.any((t) => t.name.toLowerCase().contains(query)));
          final peopleMatch = taskRecords.any(
              (r) => r.people.any((p) => p.name.toLowerCase().contains(query)));

          final metadataMatches = taskNameMatches ||
              projectNameMatches ||
              categoryNameMatches ||
              tagsMatch ||
              peopleMatch;

          if (!metadataMatches) {
            filteredEntries = entries
                .where((e) => e.note.toLowerCase().contains(query))
                .toList();
          }
        }

        if (filteredEntries.isEmpty) {
          continue;
        }

        taskGroups.add(
          TaskNoteGroup(
            workItem: workItem,
            project: project,
            category: promotedCategory,
            classification: promotedClassification,
            timesheetCode: promotedCode,
            tags: promotedTags,
            people: promotedPeople,
            entries: filteredEntries,
            totalDuration: totalTaskDuration,
            sessionCount: taskRecords.length,
            promotedFields: promotedFields,
          ),
        );
      }

      if (taskGroups.isEmpty) {
        continue;
      }

      // Sort task groups by the earliest session timestamp
      taskGroups.sort((a, b) =>
          a.entries.first.timestamp.compareTo(b.entries.first.timestamp));

      final dayTotalDuration = taskGroups.fold<Duration>(
        Duration.zero,
        (sum, tg) => sum + tg.totalDuration,
      );
      final dayTotalNotes = taskGroups.fold<int>(
        0,
        (sum, tg) => sum + tg.entries.length,
      );

      dayGroups.add(
        NotesDayGroup(
          day: day,
          taskGroups: taskGroups,
          totalDuration: dayTotalDuration,
          noteCount: dayTotalNotes,
          taskCount: taskGroups.length,
        ),
      );
    }

    final totalNotes = dayGroups.fold<int>(0, (sum, dg) => sum + dg.noteCount);
    final totalTasks = dayGroups.fold<int>(0, (sum, dg) => sum + dg.taskCount);
    final totalDuration = dayGroups.fold<Duration>(
        Duration.zero, (sum, dg) => sum + dg.totalDuration);

    return TimeNotesReport(
      dayGroups: dayGroups,
      totalNotes: totalNotes,
      totalTasks: totalTasks,
      totalDuration: totalDuration,
      unnotedSessions: globalUnnotedSessions,
      isSingleDay: isSingleDay,
    );
  }
}
