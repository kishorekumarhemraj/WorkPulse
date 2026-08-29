import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/time_note_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/time_notes_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/features/reports/widgets/session_metadata.dart';

void main() {
  group('TimeNotesService', () {
    const service = TimeNotesService();
    final now = DateTime.utc(2026, 8, 23, 14, 0);

    final project = Project(
      id: 'p1',
      workspaceId: 'ws-1',
      name: 'WorkPulse Core',
      colorHex: '#0A84FF',
      timesheetCode: 'PRJ-100',
      createdAt: now,
      updatedAt: now,
    );

    final catDev = Category(
      id: 'c1',
      workspaceId: 'ws-1',
      name: 'Development',
      iconName: 'code',
      createdAt: now,
      updatedAt: now,
    );

    final catMeet = Category(
      id: 'c2',
      workspaceId: 'ws-1',
      name: 'Meeting',
      iconName: 'people',
      createdAt: now,
      updatedAt: now,
    );

    final tag1 =
        Tag(id: 'tg1', workspaceId: 'ws-1', name: 'billing', createdAt: now);
    final tag2 =
        Tag(id: 'tg2', workspaceId: 'ws-1', name: 'api', createdAt: now);

    final taskA = WorkItem(
      id: 't1',
      workspaceId: 'ws-1',
      name: 'Task Alpha',
      projectId: 'p1',
      categoryId: 'c1',
      createdAt: now,
      updatedAt: now,
    );

    final taskB = WorkItem(
      id: 't2',
      workspaceId: 'ws-1',
      name: 'Task Beta',
      notes: 'Fallback note for Task Beta',
      projectId: 'p1',
      categoryId: 'c1',
      createdAt: now,
      updatedAt: now,
    );

    const resolver = TimesheetCodeResolver(
      codesByProject: {
        'p1': {'': 'PRJ-100'},
      },
    );

    final range = DateRange(
      start: DateTime.utc(2026, 8, 20),
      end: DateTime.utc(2026, 8, 25),
    );

    test(
        'groups multiple sessions on one task into forward chronological entries',
        () {
      final s1 = Session(
        id: 's1',
        workItemId: 't1',
        startTime: DateTime.utc(2026, 8, 23, 9, 0),
        endTime: DateTime.utc(2026, 8, 23, 10, 0),
        notes: 'First hour: setup and schema',
        createdAt: DateTime.utc(2026, 8, 23, 9, 0),
      );
      final s2 = Session(
        id: 's2',
        workItemId: 't1',
        startTime: DateTime.utc(2026, 8, 23, 11, 0),
        endTime: DateTime.utc(2026, 8, 23, 12, 30),
        notes: 'Second hour: business logic',
        createdAt: DateTime.utc(2026, 8, 23, 11, 0),
      );

      final r1 = SessionExportRecord(
        session: s1,
        workItem: taskA,
        project: project,
        category: catDev,
        classification: FinancialClassification.capex,
        grossDuration: const Duration(hours: 1),
        idleDuration: Duration.zero,
        netActiveDuration: const Duration(hours: 1),
      );
      final r2 = SessionExportRecord(
        session: s2,
        workItem: taskA,
        project: project,
        category: catDev,
        classification: FinancialClassification.capex,
        grossDuration: const Duration(minutes: 90),
        idleDuration: Duration.zero,
        netActiveDuration: const Duration(minutes: 90),
      );

      // Pass in reverse order to verify sorting
      final report = service.buildReport(
        records: [r2, r1],
        codes: resolver,
        range: range,
        isSingleDay: true,
      );

      expect(report.totalNotes, 2);
      expect(report.totalTasks, 1);
      expect(report.totalDuration, const Duration(minutes: 150));
      expect(report.unnotedSessions, 0);

      final group = report.dayGroups.first.taskGroups.first;
      expect(group.entries.length, 2);
      expect(group.entries[0].note, 'First hour: setup and schema');
      expect(group.entries[1].note, 'Second hour: business logic');
      expect(group.promotedFields, contains(SessionMetadataField.category));
      expect(
          group.promotedFields, contains(SessionMetadataField.classification));
      expect(
          group.promotedFields, contains(SessionMetadataField.timesheetCode));
    });

    test(
        'promotes unanimous metadata and keeps varying metadata at session level',
        () {
      final s1 = Session(
        id: 's1',
        workItemId: 't1',
        startTime: DateTime.utc(2026, 8, 23, 9, 0),
        endTime: DateTime.utc(2026, 8, 23, 10, 0),
        notes: 'Coding session',
        createdAt: DateTime.utc(2026, 8, 23, 9, 0),
      );
      final s2 = Session(
        id: 's2',
        workItemId: 't1',
        startTime: DateTime.utc(2026, 8, 23, 14, 0),
        endTime: DateTime.utc(2026, 8, 23, 15, 0),
        notes: 'Review meeting',
        createdAt: DateTime.utc(2026, 8, 23, 14, 0),
      );

      final r1 = SessionExportRecord(
        session: s1,
        workItem: taskA,
        project: project,
        category: catDev,
        tags: [tag1],
        classification: FinancialClassification.capex,
        grossDuration: const Duration(hours: 1),
        idleDuration: Duration.zero,
        netActiveDuration: const Duration(hours: 1),
      );
      final r2 = SessionExportRecord(
        session: s2,
        workItem: taskA,
        project: project,
        category: catMeet, // Different category
        tags: [tag1, tag2], // Different tags
        classification: FinancialClassification.capex,
        grossDuration: const Duration(hours: 1),
        idleDuration: Duration.zero,
        netActiveDuration: const Duration(hours: 1),
      );

      final report = service.buildReport(
        records: [r1, r2],
        codes: resolver,
        range: range,
        isSingleDay: true,
      );

      final group = report.dayGroups.first.taskGroups.first;
      expect(group.promotedFields, contains(SessionMetadataField.project));
      expect(
          group.promotedFields, contains(SessionMetadataField.classification));
      expect(
          group.promotedFields, isNot(contains(SessionMetadataField.category)));
      expect(group.promotedFields, isNot(contains(SessionMetadataField.tags)));
    });

    test('uses task fallback note when sessions have no notes', () {
      final s1 = Session(
        id: 's1',
        workItemId: 't2',
        startTime: DateTime.utc(2026, 8, 23, 10, 0),
        endTime: DateTime.utc(2026, 8, 23, 11, 0),
        notes: null,
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
      );

      final r1 = SessionExportRecord(
        session: s1,
        workItem: taskB,
        project: project,
        category: catDev,
        grossDuration: const Duration(hours: 1),
        idleDuration: Duration.zero,
        netActiveDuration: const Duration(hours: 1),
      );

      final report = service.buildReport(
        records: [r1],
        codes: resolver,
        range: range,
        isSingleDay: true,
      );

      expect(report.totalNotes, 1);
      final group = report.dayGroups.first.taskGroups.first;
      expect(group.entries.first.source, TimeNoteSource.taskFallback);
      expect(group.entries.first.note, 'Fallback note for Task Beta');
    });

    test('counts unnoted sessions accurately', () {
      final taskNoNotes = WorkItem(
        id: 't3',
        workspaceId: 'ws-1',
        name: 'Task Gamma',
        projectId: 'p1',
        categoryId: 'c1',
        createdAt: now,
        updatedAt: now,
      );

      final s1 = Session(
        id: 's1',
        workItemId: 't3',
        startTime: DateTime.utc(2026, 8, 23, 10, 0),
        endTime: DateTime.utc(2026, 8, 23, 11, 0),
        notes: null,
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
      );

      final r1 = SessionExportRecord(
        session: s1,
        workItem: taskNoNotes,
        project: project,
        grossDuration: const Duration(hours: 1),
        idleDuration: Duration.zero,
        netActiveDuration: const Duration(hours: 1),
      );

      final report = service.buildReport(
        records: [r1],
        codes: resolver,
        range: range,
        isSingleDay: true,
      );

      expect(report.totalNotes, 0);
      expect(report.unnotedSessions, 1);
      expect(report.isEmpty, isTrue);
    });

    test('filters report by search query across notes and metadata', () {
      final s1 = Session(
        id: 's1',
        workItemId: 't1',
        startTime: DateTime.utc(2026, 8, 23, 9, 0),
        endTime: DateTime.utc(2026, 8, 23, 10, 0),
        notes: 'Refactored backend auth',
        createdAt: DateTime.utc(2026, 8, 23, 9, 0),
      );
      final s2 = Session(
        id: 's2',
        workItemId: 't1',
        startTime: DateTime.utc(2026, 8, 23, 11, 0),
        endTime: DateTime.utc(2026, 8, 23, 12, 0),
        notes: 'Updated database migrations',
        createdAt: DateTime.utc(2026, 8, 23, 11, 0),
      );

      final r1 = SessionExportRecord(
        session: s1,
        workItem: taskA,
        project: project,
        category: catDev,
        grossDuration: const Duration(hours: 1),
        idleDuration: Duration.zero,
        netActiveDuration: const Duration(hours: 1),
      );
      final r2 = SessionExportRecord(
        session: s2,
        workItem: taskA,
        project: project,
        category: catDev,
        grossDuration: const Duration(hours: 1),
        idleDuration: Duration.zero,
        netActiveDuration: const Duration(hours: 1),
      );

      final matchReport = service.buildReport(
        records: [r1, r2],
        codes: resolver,
        searchQuery: 'auth',
        range: range,
        isSingleDay: true,
      );

      expect(matchReport.totalNotes, 1);
      expect(matchReport.dayGroups.first.taskGroups.first.entries.first.note,
          'Refactored backend auth');

      final noMatchReport = service.buildReport(
        records: [r1, r2],
        codes: resolver,
        searchQuery: 'nonexistent',
        range: range,
        isSingleDay: true,
      );

      expect(noMatchReport.totalNotes, 0);
      expect(noMatchReport.isEmpty, isTrue);
    });
  });
}
