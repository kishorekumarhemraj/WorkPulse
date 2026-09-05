import 'package:equatable/equatable.dart';

/// A day on the wall calendar — not an instant.
///
/// A due date of 3 September is 3 September in every timezone and on both
/// sides of a DST boundary. Storing it as a `DateTime` means storing an
/// instant, and an instant converted to UTC for storage lands on the previous
/// day for anyone east of Greenwich — which is exactly what
/// `attribute_values.date_value` does today (see docs, F2).
///
/// This type exists so that mistake cannot be made twice: there is no
/// implicit conversion to `DateTime`, and the only ways in are
/// [CalendarDate.fromLocal], [CalendarDate.parse], [CalendarDate.tryParse]
/// and the constructor.
class CalendarDate extends Equatable implements Comparable<CalendarDate> {
  final int year;
  final int month;
  final int day;

  const CalendarDate(this.year, this.month, this.day);

  /// The calendar day [instant] falls on *in the machine's local zone*.
  factory CalendarDate.fromLocal(DateTime instant) {
    final local = instant.toLocal();
    return CalendarDate(local.year, local.month, local.day);
  }

  /// 'YYYY-MM-DD'. Returns null for anything malformed rather than throwing:
  /// a corrupt row must not crash the Work Items screen.
  static CalendarDate? tryParse(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    final parts = trimmed.split('-');
    if (parts.length != 3) return null;
    if (parts[0].length != 4 || parts[1].length != 2 || parts[2].length != 2) {
      return null;
    }

    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);

    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12) return null;
    if (d < 1 || d > 31) return null;

    // Validate real calendar date (e.g., leap years, 30-day months)
    final check = DateTime.utc(y, m, d);
    if (check.year != y || check.month != m || check.day != d) {
      return null;
    }

    return CalendarDate(y, m, d);
  }

  /// 'YYYY-MM-DD'. Throws [FormatException] if [value] cannot be parsed.
  factory CalendarDate.parse(String value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw FormatException('Invalid CalendarDate format: $value');
    }
    return parsed;
  }

  /// 'YYYY-MM-DD' — zero-padded, so text ordering equals date ordering and
  /// SQLite can sort and range-filter on the column directly.
  String toStorageString() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Midday local, never midnight. Midnight does not exist on spring-forward
  /// days in some zones; midday always does. Used only at the UI boundary,
  /// for `showDatePicker` and `DateFormat`.
  DateTime toLocalDateTime() {
    return DateTime(year, month, day, 12, 0, 0);
  }

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  bool operator <(CalendarDate other) => compareTo(other) < 0;
  bool operator <=(CalendarDate other) => compareTo(other) <= 0;
  bool operator >(CalendarDate other) => compareTo(other) > 0;
  bool operator >=(CalendarDate other) => compareTo(other) >= 0;

  /// Number of days between this date and [other] (`this - other`).
  /// Positive when this date is after [other], negative when before.
  int differenceInDays(CalendarDate other) {
    final thisUtc = DateTime.utc(year, month, day);
    final otherUtc = DateTime.utc(other.year, other.month, other.day);
    return thisUtc.difference(otherUtc).inDays;
  }

  /// Returns a new [CalendarDate] with [days] added.
  CalendarDate addDays(int days) {
    final utc = DateTime.utc(year, month, day).add(Duration(days: days));
    return CalendarDate(utc.year, utc.month, utc.day);
  }

  /// 1 (Monday) to 7 (Sunday), matching [DateTime.monday]..[DateTime.sunday].
  int get weekday => DateTime.utc(year, month, day).weekday;

  /// Whether this date falls on Saturday or Sunday.
  bool get isWeekend =>
      weekday == DateTime.saturday || weekday == DateTime.sunday;

  @override
  List<Object?> get props => [year, month, day];

  @override
  String toString() => toStorageString();
}
