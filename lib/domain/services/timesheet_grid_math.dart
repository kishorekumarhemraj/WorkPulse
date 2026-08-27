/// Pure math and day-attribution utilities for the Timesheet Entry Grid.
///
/// These functions contain no Flutter or database dependencies and handle
/// daylight saving, calendar midnight rollover, cell rounding, and greedy
/// two-column section packing.
library;

/// How much of [spanStart, spanEnd) falls inside the local calendar day
/// beginning at [dayStart].
///
/// [dayStart] should be a local midnight. [spanStart] and [spanEnd] must
/// be in the same local timezone as [dayStart].
Duration overlapOnDay(
  DateTime spanStart,
  DateTime spanEnd,
  DateTime dayStart,
) {
  // DateTime(y, m, d + 1) rolls months and years correctly, and lands on the
  // next local midnight even when that day is 23 or 25 hours long (DST). Adding
  // Duration(days: 1) does not.
  final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
  final s = spanStart.isAfter(dayStart) ? spanStart : dayStart;
  final e = spanEnd.isBefore(dayEnd) ? spanEnd : dayEnd;
  return e.isAfter(s) ? e.difference(s) : Duration.zero;
}

/// Local midnight of the week containing [date], on [weekStartDay].
///
/// [weekStartDay] follows Dart's convention (1 = Monday, 7 = Sunday).
DateTime weekStartFor(DateTime date, int weekStartDay) {
  final day = DateTime(date.year, date.month, date.day);
  final delta = (day.weekday - weekStartDay + 7) % 7;
  return DateTime(day.year, day.month, day.day - delta);
}

/// One cell, rounded to [increment] hours and cleaned of floating-point dust.
///
/// `toStringAsFixed(2)` then reparse ensures increments like 0.05 and 0.01 do
/// not produce floating-point dust like 8.499999999999998.
double roundCell(Duration d, double increment) {
  if (d <= Duration.zero || increment <= 0) return 0;
  final hours = d.inSeconds / 3600.0;
  final steps = (hours / increment).round();
  return double.parse((steps * increment).toStringAsFixed(2));
}

/// Any total of cells. Re-rounded to kill accumulated dust from summing doubles.
double sumCells(Iterable<double> cells) =>
    double.parse(cells.fold(0.0, (a, b) => a + b).toStringAsFixed(2));

/// Formats rounded hours for grid display. Zero renders as empty string.
String formatCell(double hours) => hours == 0 ? '' : hours.toStringAsFixed(2);

/// Splits [sections] across two columns, each going to whichever column is
/// currently shorter.
///
/// Greedy rather than optimal: keeps sections close to their intended reading
/// order while balancing vertical height across 2 columns.
List<List<T>> packIntoTwoColumns<T>(
  List<T> sections,
  double Function(T) estimateHeight,
) {
  final columns = [<T>[], <T>[]];
  final heights = [0.0, 0.0];
  for (final section in sections) {
    final target = heights[0] <= heights[1] ? 0 : 1;
    columns[target].add(section);
    heights[target] += estimateHeight(section);
  }
  return columns;
}
