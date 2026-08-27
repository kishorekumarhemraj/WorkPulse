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

void main() {
  group('TimesheetGridMath Unit Tests', () {
    group('overlapOnDay', () {
      test('session from 23:30 to 00:30 puts 30 minutes on each of two days', () {
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
        // Spanning across 3 calendar days (e.g. 48 hour marathon)
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
        // Wednesday 2026-08-26
        final wed = DateTime(2026, 8, 26, 14, 30);
        final start = weekStartFor(wed, DateTime.saturday);

        expect(start, DateTime(2026, 8, 22));
        expect(start.weekday, DateTime.saturday);
      });

      test('Saturday week start: Saturday date yields same day at midnight', () {
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
      test('5 cells of 1h20m at 0.01 increment give row total 6.65, not 6.67', () {
        final cellDuration = const Duration(hours: 1, minutes: 20); // 1.3333...
        final cell = roundCell(cellDuration, 0.01);
        expect(cell, 1.33);

        final cells = [cell, cell, cell, cell, cell];
        final rowTotal = sumCells(cells);
        expect(rowTotal, 6.65);

        // Exact total would be 5 * 1h20m = 6h40m = 6.6667h (rounded 6.67)
        // Showing 6.65 prevents timesheet portal mismatch
        final exact = cellDuration * 5;
        expect(exact.inSeconds / 3600.0, closeTo(6.6667, 0.0001));
      });

      test('increment 0.25 rounds 1h20m to 1.25 and 1h24m to 1.50', () {
        expect(roundCell(const Duration(hours: 1, minutes: 20), 0.25), 1.25);
        expect(roundCell(const Duration(hours: 1, minutes: 24), 0.25), 1.50);
        expect(roundCell(const Duration(minutes: 7), 0.25), 0.0);
        expect(roundCell(const Duration(minutes: 8), 0.25), 0.25);
      });

      test('increment 0.05 rounds to 3-minute steps cleanly without float noise', () {
        expect(roundCell(const Duration(hours: 8, minutes: 30), 0.05), 8.50);
        expect(roundCell(const Duration(minutes: 2), 0.05), 0.05);
      });

      test('zero duration returns 0.0', () {
        expect(roundCell(Duration.zero, 0.25), 0.0);
        expect(roundCell(const Duration(seconds: -10), 0.25), 0.0);
      });

      test('formatCell renders empty string for 0, formatted 2 decimals otherwise', () {
        expect(formatCell(0.0), '');
        expect(formatCell(1.0), '1.00');
        expect(formatCell(1.5), '1.50');
        expect(formatCell(0.25), '0.25');
      });
    });
  });
}
