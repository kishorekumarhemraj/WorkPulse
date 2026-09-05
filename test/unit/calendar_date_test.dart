import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/models/calendar_date.dart';

void main() {
  group('CalendarDate', () {
    test('constructs and converts to/from storage string', () {
      const date = CalendarDate(2026, 9, 3);
      expect(date.toStorageString(), '2026-09-03');
      expect(date.year, 2026);
      expect(date.month, 9);
      expect(date.day, 3);

      final parsed = CalendarDate.parse('2026-09-03');
      expect(parsed, equals(date));
      expect(parsed.toStorageString(), '2026-09-03');
    });

    test('tryParse returns null on malformed strings and invalid dates', () {
      expect(CalendarDate.tryParse(null), isNull);
      expect(CalendarDate.tryParse(''), isNull);
      expect(CalendarDate.tryParse('invalid'), isNull);
      expect(CalendarDate.tryParse('2026-02-30'), isNull); // Feb 30 invalid
      expect(CalendarDate.tryParse('2026-13-01'), isNull); // Month 13 invalid
      expect(CalendarDate.tryParse('2026-04-31'), isNull); // Apr 31 invalid
      expect(CalendarDate.tryParse('2026-9-3'), isNull); // Not YYYY-MM-DD
    });

    test('parses valid leap year date', () {
      expect(CalendarDate.tryParse('2024-02-29'), isNotNull);
      expect(CalendarDate.tryParse('2023-02-29'), isNull);
    });

    test('fromLocal extracts local calendar day', () {
      final dt = DateTime(2026, 9, 3, 23, 45);
      final date = CalendarDate.fromLocal(dt);
      expect(date, equals(const CalendarDate(2026, 9, 3)));
    });

    test('toLocalDateTime returns local midday (12:00:00)', () {
      const date = CalendarDate(2026, 9, 3);
      final ldt = date.toLocalDateTime();
      expect(ldt.year, 2026);
      expect(ldt.month, 9);
      expect(ldt.day, 3);
      expect(ldt.hour, 12);
      expect(ldt.minute, 0);
      expect(ldt.second, 0);
    });

    test('compareTo and operators order correctly', () {
      const d1 = CalendarDate(2026, 9, 3);
      const d2 = CalendarDate(2026, 9, 4);
      const d3 = CalendarDate(2026, 10, 1);
      const d4 = CalendarDate(2027, 1, 1);

      expect(d1.compareTo(d2), lessThan(0));
      expect(d2.compareTo(d1), greaterThan(0));
      expect(d1.compareTo(const CalendarDate(2026, 9, 3)), 0);

      expect(d1 < d2, isTrue);
      expect(d1 <= d2, isTrue);
      expect(d2 > d1, isTrue);
      expect(d2 >= d1, isTrue);
      expect(d2 < d3, isTrue);
      expect(d3 < d4, isTrue);
    });

    test('differenceInDays computes day differences across months and years',
        () {
      const d1 = CalendarDate(2026, 9, 3);
      const d2 = CalendarDate(2026, 9, 10);
      expect(d2.differenceInDays(d1), 7);
      expect(d1.differenceInDays(d2), -7);

      const dYearEnd = CalendarDate(2026, 12, 31);
      const dYearStart = CalendarDate(2027, 1, 1);
      expect(dYearStart.differenceInDays(dYearEnd), 1);
    });

    test('addDays handles positive and negative day additions', () {
      const d1 = CalendarDate(2026, 9, 3);
      expect(d1.addDays(5), equals(const CalendarDate(2026, 9, 8)));
      expect(d1.addDays(-4), equals(const CalendarDate(2026, 8, 30)));
    });

    test('weekday and isWeekend work as expected', () {
      // 2026-09-03 is a Thursday (weekday 4)
      const thu = CalendarDate(2026, 9, 3);
      expect(thu.weekday, DateTime.thursday);
      expect(thu.isWeekend, isFalse);

      // 2026-09-05 is Saturday
      const sat = CalendarDate(2026, 9, 5);
      expect(sat.weekday, DateTime.saturday);
      expect(sat.isWeekend, isTrue);

      // 2026-09-06 is Sunday
      const sun = CalendarDate(2026, 9, 6);
      expect(sun.weekday, DateTime.sunday);
      expect(sun.isWeekend, isTrue);
    });
  });
}
