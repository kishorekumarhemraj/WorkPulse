import 'package:equatable/equatable.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/features/reports/widgets/session_metadata.dart';

enum TimeNoteSource {
  /// Note written on a specific session.
  session,

  /// Fallback note taken from the work item when sessions have no notes.
  taskFallback,
}

/// One note entry originating either from a session or as a task-level fallback.
class TimeNoteEntry extends Equatable {
  final SessionExportRecord record;
  final String note;
  final TimeNoteSource source;
  final DateTime timestamp;
  final Duration duration;

  const TimeNoteEntry({
    required this.record,
    required this.note,
    required this.source,
    required this.timestamp,
    required this.duration,
  });

  @override
  List<Object?> get props => [record.session.id, note, source, timestamp, duration];
}

/// All notes and sessions for a single task within a calendar day.
class TaskNoteGroup extends Equatable {
  final WorkItem workItem;
  final Project? project;
  final Category? category;
  final FinancialClassification classification;
  final TimesheetCodeResolution? timesheetCode;
  final List<Tag> tags;
  final List<Person> people;
  final List<TimeNoteEntry> entries;
  final Duration totalDuration;
  final int sessionCount;
  final Set<SessionMetadataField> promotedFields;

  const TaskNoteGroup({
    required this.workItem,
    this.project,
    this.category,
    this.classification = FinancialClassification.none,
    this.timesheetCode,
    this.tags = const [],
    this.people = const [],
    required this.entries,
    required this.totalDuration,
    required this.sessionCount,
    this.promotedFields = const {},
  });

  SessionExportRecord get representativeRecord => entries.first.record;

  @override
  List<Object?> get props => [
        workItem.id,
        project?.id,
        category?.id,
        classification,
        timesheetCode,
        tags,
        people,
        entries,
        totalDuration,
        sessionCount,
        promotedFields,
      ];
}

/// One calendar day of task note groups.
class NotesDayGroup extends Equatable {
  final DateTime day;
  final List<TaskNoteGroup> taskGroups;
  final Duration totalDuration;
  final int noteCount;
  final int taskCount;

  const NotesDayGroup({
    required this.day,
    required this.taskGroups,
    required this.totalDuration,
    required this.noteCount,
    required this.taskCount,
  });

  @override
  List<Object?> get props => [day, taskGroups, totalDuration, noteCount, taskCount];
}

/// Complete report of time notes for a date range.
class TimeNotesReport extends Equatable {
  final List<NotesDayGroup> dayGroups;
  final int totalNotes;
  final int totalTasks;
  final Duration totalDuration;
  final int unnotedSessions;
  final bool isSingleDay;

  const TimeNotesReport({
    required this.dayGroups,
    required this.totalNotes,
    required this.totalTasks,
    required this.totalDuration,
    required this.unnotedSessions,
    required this.isSingleDay,
  });

  bool get isEmpty => dayGroups.isEmpty || totalNotes == 0;

  @override
  List<Object?> get props => [
        dayGroups,
        totalNotes,
        totalTasks,
        totalDuration,
        unnotedSessions,
        isSingleDay,
      ];
}
