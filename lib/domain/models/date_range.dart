import 'package:equatable/equatable.dart';

/// A pure-Dart date range with [start] and [end] boundaries.
///
/// Replaces Flutter's `DateTimeRange` in the domain layer to maintain
/// the architectural invariant that `lib/domain/` has zero Flutter imports.
class DateRange extends Equatable {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  /// Total duration of this range.
  Duration get duration => end.difference(start);

  @override
  List<Object?> get props => [start, end];

  @override
  String toString() => 'DateRange(start: $start, end: $end)';
}
