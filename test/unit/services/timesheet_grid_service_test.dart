import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/domain/services/timesheet_service.dart';
import 'package:workpulse/domain/services/timesheet_grid_math.dart';

SessionExportRecord _createRecord({
  required String id,
  required String taskId,
  required String taskName,
  required String projectId,
  required String projectName,
  String? timesheetCode,
  FinancialClassification taskClassification = FinancialClassification.none,
  FinancialClassification? sessionClassification,
  required DateTime startTime,
  required DateTime endTime,
  List<IdlePeriod> idlePeriods = const [],
}) {
  final session = Session(
    id: id,
    workItemId: taskId,
    startTime: startTime,
    endTime: endTime,
    financialClassification: sessionClassification,
    createdAt: startTime,
  );
  final workItem = WorkItem(
    id: taskId,
    name: taskName,
    workspaceId: 'ws-1',
    projectId: projectId,
    categoryId: 'cat-1',
    financialClassification: taskClassification,
    createdAt: startTime,
    updatedAt: startTime,
  );
  final project = Project(
    id: projectId,
    name: projectName,
    workspaceId: 'ws-1',
    timesheetCode: timesheetCode,
    createdAt: startTime,
    updatedAt: startTime,
  );

  final gross = endTime.difference(startTime);
  var idleTotal = Duration.zero;
  for (final p in idlePeriods) {
    if (p.resolution == IdleResolution.markIdle) {
      idleTotal += p.duration;
    }
  }

  return SessionExportRecord(
    session: session,
    workItem: workItem,
    project: project,
    grossDuration: gross,
    idleDuration: idleTotal,
    netActiveDuration: gross > idleTotal ? gross - idleTotal : Duration.zero,
    classification: sessionClassification ?? taskClassification,
    idlePeriods: idlePeriods,
  );
}

void main() {
  group('TimesheetGridMath Unit Tests', () {
    group('overlapOnDay', () {
      test('session from 23:30 to 00:30 puts 30 minutes on each of two days',
          () {
        final day1 = DateTime(2026, 8, 22); // Saturday local midnight
        final day2 = DateTime(2026, 8, 23); // Sunday local midnight

        final start = DateTime(2026, 8, 22, 23, 30);
        final end = DateTime(2026, 8, 23, 0, 30);

        final overlapDay1 = overlapOnDay(start, end, day1);
        final overlapDay2 = overlapOnDay(start, end, day2);

        expect(overlapDay1, const Duration(minutes: 30));
        expect(overlapDay2, const Duration(minutes: 30));
        expect(overlapDay1 + overlapDay2, const Duration(hours: 1));
      });

      test('per-day parts of closed session sum exactly to gross duration', () {
        final day1 = DateTime(2026, 8, 20);
        final day2 = DateTime(2026, 8, 21);
        final day3 = DateTime(2026, 8, 22);
        final day4 = DateTime(2026, 8, 23);

        final start = DateTime(2026, 8, 20, 10, 15);
        final end = DateTime(2026, 8, 22, 16, 45);

        final gross = end.difference(start);

        final o1 = overlapOnDay(start, end, day1);
        final o2 = overlapOnDay(start, end, day2);
        final o3 = overlapOnDay(start, end, day3);
        final o4 = overlapOnDay(start, end, day4);

        expect(o1 + o2 + o3 + o4, gross);
        expect(o4, Duration.zero);
        expect(o1, const Duration(hours: 13, minutes: 45));
        expect(o2, const Duration(hours: 24));
        expect(o3, const Duration(hours: 16, minutes: 45));
      });

      test('session outside day produces zero duration', () {
        final day = DateTime(2026, 8, 25);
        final start = DateTime(2026, 8, 20, 9, 0);
        final end = DateTime(2026, 8, 20, 17, 0);

        expect(overlapOnDay(start, end, day), Duration.zero);
      });
    });

    group('weekStartFor', () {
      test('Saturday week start: Wednesday date yields previous Saturday', () {
        final wed = DateTime(2026, 8, 26, 14, 30);
        final start = weekStartFor(wed, DateTime.saturday);

        expect(start, DateTime(2026, 8, 22));
        expect(start.weekday, DateTime.saturday);
      });

      test('Saturday week start: Saturday date yields same day at midnight',
          () {
        final sat = DateTime(2026, 8, 22, 23, 59);
        final start = weekStartFor(sat, DateTime.saturday);

        expect(start, DateTime(2026, 8, 22));
      });

      test('Monday week start: Wednesday date yields Monday', () {
        final wed = DateTime(2026, 8, 26, 10, 0);
        final start = weekStartFor(wed, DateTime.monday);

        expect(start, DateTime(2026, 8, 24));
        expect(start.weekday, DateTime.monday);
      });

      test('Sunday week start: Wednesday date yields Sunday', () {
        final wed = DateTime(2026, 8, 26, 10, 0);
        final start = weekStartFor(wed, DateTime.sunday);

        expect(start, DateTime(2026, 8, 23));
        expect(start.weekday, DateTime.sunday);
      });
    });

    group('roundCell & sumCells', () {
      test('5 cells of 1h20m at 0.01 increment give row total 6.65, not 6.67',
          () {
        final cellDuration = const Duration(hours: 1, minutes: 20);
        final cell = roundCell(cellDuration, 0.01);
        expect(cell, 1.33);

        final cells = [cell, cell, cell, cell, cell];
        final rowTotal = sumCells(cells);
        expect(rowTotal, 6.65);

        final exact = cellDuration * 5;
        expect(exact.inSeconds / 3600.0, closeTo(6.6667, 0.0001));
      });

      test('increment 0.25 rounds 1h20m to 1.25 and 1h24m to 1.50', () {
        expect(roundCell(const Duration(hours: 1, minutes: 20), 0.25), 1.25);
        expect(roundCell(const Duration(hours: 1, minutes: 24), 0.25), 1.50);
        expect(roundCell(const Duration(minutes: 7), 0.25), 0.0);
        expect(roundCell(const Duration(minutes: 8), 0.25), 0.25);
      });

      test(
          'increment 0.05 rounds to 3-minute steps cleanly without float noise',
          () {
        expect(roundCell(const Duration(hours: 8, minutes: 30), 0.05), 8.50);
        expect(roundCell(const Duration(minutes: 2), 0.05), 0.05);
      });

      test('zero duration returns 0.0', () {
        expect(roundCell(Duration.zero, 0.25), 0.0);
        expect(roundCell(const Duration(seconds: -10), 0.25), 0.0);
      });

      test(
          'formatCell renders empty string for 0, formatted 2 decimals otherwise',
          () {
        expect(formatCell(0.0), '');
        expect(formatCell(1.0), '1.00');
        expect(formatCell(1.5), '1.50');
        expect(formatCell(0.25), '0.25');
      });
    });
  });

  group('TimesheetService Grid Integration Tests', () {
    const service = TimesheetService();

    test('idle time is subtracted only from the day it fell on', () {
      // 2-day session from Sat 22 Aug 20:00 to Sun 23 Aug 04:00 (8 hours total)
      // Idle period on Sun 23 Aug 01:00 - 02:00 (1 hour marked idle)
      final sat = DateTime(2026, 8, 22, 20, 0);
      final sun = DateTime(2026, 8, 23, 4, 0);
      final idleStart = DateTime(2026, 8, 23, 1, 0);
      final idleEnd = DateTime(2026, 8, 23, 2, 0);

      final record = _createRecord(
        id: 's1',
        taskId: 't1',
        taskName: 'Task 1',
        projectId: 'p1',
        projectName: 'Project Alpha',
        timesheetCode: 'ALPHA01',
        taskClassification: FinancialClassification.capex,
        startTime: sat,
        endTime: sun,
        idlePeriods: [
          IdlePeriod(
            id: 'i1',
            sessionId: 's1',
            startTime: idleStart,
            endTime: idleEnd,
            resolution: IdleResolution.markIdle,
            createdAt: idleStart,
          ),
        ],
      );

      final range = DateRange(
        start: DateTime(2026, 8, 22, 0, 0),
        end: DateTime(2026, 8, 28, 23, 59),
      );

      // On Net basis:
      // Sat gross = 4h, idle = 0h -> net = 4h (4.00)
      // Sun gross = 4h, idle = 1h -> net = 3h (3.00)
      final netData = service.build(
        range: range,
        records: [record],
        definitions: const [],
        basis: TimesheetHoursBasis.net,
        weekStartDay: DateTime.saturday,
        roundingIncrement: 0.25,
      );

      expect(netData.weeks.length, 1);
      final netWeek = netData.weeks.single;
      expect(netWeek.rows.length, 1);
      final netRow = netWeek.rows.single;
      expect(netRow.cells[0], 4.00); // Sat
      expect(netRow.cells[1], 3.00); // Sun
      expect(netRow.total, 7.00);
      expect(netWeek.total, 7.00);

      // On Gross basis:
      // Sat = 4h, Sun = 4h -> total = 8h
      final grossData = service.build(
        range: range,
        records: [record],
        definitions: const [],
        basis: TimesheetHoursBasis.gross,
        weekStartDay: DateTime.saturday,
        roundingIncrement: 0.25,
      );

      final grossRow = grossData.weeks.single.rows.single;
      expect(grossRow.cells[0], 4.00);
      expect(grossRow.cells[1], 4.00);
      expect(grossRow.total, 8.00);
    });

    test('only IdleResolution.markIdle is subtracted from day', () {
      final sat = DateTime(2026, 8, 22, 10, 0);
      final satEnd = DateTime(2026, 8, 22, 14, 0); // 4h

      final record = _createRecord(
        id: 's1',
        taskId: 't1',
        taskName: 'Task 1',
        projectId: 'p1',
        projectName: 'Project Alpha',
        timesheetCode: 'ALPHA01',
        taskClassification: FinancialClassification.capex,
        startTime: sat,
        endTime: satEnd,
        idlePeriods: [
          IdlePeriod(
            id: 'i1',
            sessionId: 's1',
            startTime: DateTime(2026, 8, 22, 11, 0),
            endTime: DateTime(2026, 8, 22, 12, 0),
            resolution:
                IdleResolution.keepTracking, // keepTracking (not subtracted)
            createdAt: DateTime(2026, 8, 22, 11, 0),
          ),
        ],
      );

      final data = service.build(
        range: DateRange(start: sat, end: satEnd),
        records: [record],
        definitions: const [],
        basis: TimesheetHoursBasis.net,
      );

      expect(data.weeks.single.rows.single.cells[0], 4.00);
    });

    test('one project with CapEx and OpEx yields two rows sharing a code', () {
      final sat = DateTime(2026, 8, 22, 10, 0);
      final satEnd1 = DateTime(2026, 8, 22, 12, 0); // 2h CapEx
      final satEnd2 = DateTime(2026, 8, 22, 14, 0); // 2h OpEx

      final rec1 = _createRecord(
        id: 's1',
        taskId: 't1',
        taskName: 'Task 1 CapEx',
        projectId: 'p1',
        projectName: 'ITCMEL19',
        timesheetCode: 'ITCMEL19',
        taskClassification: FinancialClassification.capex,
        startTime: sat,
        endTime: satEnd1,
      );
      final rec2 = _createRecord(
        id: 's2',
        taskId: 't2',
        taskName: 'Task 2 OpEx',
        projectId: 'p1',
        projectName: 'ITCMEL19',
        timesheetCode: 'ITCMEL19',
        taskClassification: FinancialClassification.opex,
        startTime: satEnd1,
        endTime: satEnd2,
      );

      final data = service.build(
        range: DateRange(start: sat, end: satEnd2),
        records: [rec1, rec2],
        definitions: const [],
      );

      expect(data.weeks.single.rows.length, 2);
      final row1 = data.weeks.single.rows[0];
      final row2 = data.weeks.single.rows[1];

      expect(row1.code, 'ITCMEL19');
      expect(row1.classification, FinancialClassification.capex);
      expect(row1.cells[0], 2.00);

      expect(row2.code, 'ITCMEL19');
      expect(row2.classification, FinancialClassification.opex);
      expect(row2.cells[0], 2.00);
    });

    test('rows sort by code then classification, uncodeable row sorts last',
        () {
      final sat = DateTime(2026, 8, 22, 9, 0);

      final recNoCode = _createRecord(
        id: 's0',
        taskId: 't0',
        taskName: 'No Code Task',
        projectId: 'p0',
        projectName: 'Unknown Project',
        timesheetCode: null,
        taskClassification: FinancialClassification.capex,
        startTime: sat,
        endTime: sat.add(const Duration(hours: 10)), // 10h
      );
      final recVeeva = _createRecord(
        id: 's1',
        taskId: 't1',
        taskName: 'Veeva Task',
        projectId: 'p1',
        projectName: 'Veeva',
        timesheetCode: 'VEEVA026',
        taskClassification: FinancialClassification.capex,
        startTime: sat,
        endTime: sat.add(const Duration(hours: 2)), // 2h
      );
      final recItcmelOpEx = _createRecord(
        id: 's2',
        taskId: 't2',
        taskName: 'ITCMEL OpEx',
        projectId: 'p2',
        projectName: 'ITCMEL',
        timesheetCode: 'ITCMEL19',
        taskClassification: FinancialClassification.opex,
        startTime: sat,
        endTime: sat.add(const Duration(hours: 1)),
      );
      final recItcmelCapEx = _createRecord(
        id: 's3',
        taskId: 't3',
        taskName: 'ITCMEL CapEx',
        projectId: 'p2',
        projectName: 'ITCMEL',
        timesheetCode: 'ITCMEL19',
        taskClassification: FinancialClassification.capex,
        startTime: sat,
        endTime: sat.add(const Duration(hours: 1)),
      );

      final data = service.build(
        range: DateRange(start: sat, end: sat.add(const Duration(days: 6))),
        records: [recNoCode, recVeeva, recItcmelOpEx, recItcmelCapEx],
        definitions: const [],
      );

      final rows = data.weeks.single.rows;
      expect(rows.length, 4);

      // Order should be:
      // 1. ITCMEL19 - CapEx
      // 2. ITCMEL19 - OpEx
      // 3. VEEVA026 - CapEx
      // 4. '' / 'No timesheet code' - CapEx
      expect(rows[0].code, 'ITCMEL19');
      expect(rows[0].classification, FinancialClassification.capex);

      expect(rows[1].code, 'ITCMEL19');
      expect(rows[1].classification, FinancialClassification.opex);

      expect(rows[2].code, 'VEEVA026');
      expect(rows[2].classification, FinancialClassification.capex);

      expect(rows[3].code, '');
      expect(rows[3].codeLabel, timesheetNoCodeLabel);
    });

    test(
        '1-month range yields multiple ascending week blocks and truncates at 6',
        () {
      final records = <SessionExportRecord>[];
      final monthStart = DateTime(2026, 8, 1, 10, 0);

      // Add a session in each of 8 consecutive weeks
      for (var w = 0; w < 8; w++) {
        final start = DateTime(
            monthStart.year, monthStart.month, monthStart.day + (w * 7), 10, 0);
        records.add(_createRecord(
          id: 's_$w',
          taskId: 't_$w',
          taskName: 'Task $w',
          projectId: 'p1',
          projectName: 'Project 1',
          timesheetCode: 'PROJ01',
          taskClassification: FinancialClassification.capex,
          startTime: start,
          endTime: start.add(const Duration(hours: 2)),
        ));
      }

      final longRange = DateRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 10, 1),
      );

      final data = service.build(
        range: longRange,
        records: records,
        definitions: const [],
      );

      expect(data.weeks.length, maxTimesheetWeeks);
      expect(data.weeksTruncated, isTrue);

      // Ascending dates
      for (var i = 0; i < data.weeks.length - 1; i++) {
        expect(data.weeks[i].start.isBefore(data.weeks[i + 1].start), isTrue);
      }
    });

    test('empty week without sessions is omitted', () {
      final satWeek1 = DateTime(2026, 8, 22, 10, 0);
      final satWeek3 = DateTime(2026, 9, 5, 10, 0);

      final rec1 = _createRecord(
        id: 's1',
        taskId: 't1',
        taskName: 'Task 1',
        projectId: 'p1',
        projectName: 'P1',
        timesheetCode: 'P1',
        startTime: satWeek1,
        endTime: satWeek1.add(const Duration(hours: 2)),
      );
      final rec3 = _createRecord(
        id: 's3',
        taskId: 't3',
        taskName: 'Task 3',
        projectId: 'p1',
        projectName: 'P1',
        timesheetCode: 'P1',
        startTime: satWeek3,
        endTime: satWeek3.add(const Duration(hours: 2)),
      );

      final data = service.build(
        range: DateRange(
          start: DateTime(2026, 8, 22),
          end: DateTime(2026, 9, 10),
        ),
        records: [rec1, rec3],
        definitions: const [],
      );

      // Week 1 (start 8/22) and Week 3 (start 9/5) exist, Week 2 (start 8/29) omitted
      expect(data.weeks.length, 2);
      expect(data.weeks[0].start, DateTime(2026, 8, 22));
      expect(data.weeks[1].start, DateTime(2026, 9, 5));
    });
  });
}
