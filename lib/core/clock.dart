/// Abstraction over the system clock for deterministic testing.
///
/// Services that need the current time should accept a [Clock] parameter
/// instead of calling `DateTime.now()` directly. In production, use
/// [SystemClock]. In tests, use [FakeClock] with a fixed or advancing time.
abstract class Clock {
  DateTime now();
}

/// Default clock that delegates to [DateTime.now] in UTC.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// Test clock with a controllable time value.
///
/// ```dart
/// final clock = FakeClock(DateTime.utc(2026, 1, 15, 10, 0, 0));
/// expect(clock.now(), DateTime.utc(2026, 1, 15, 10, 0, 0));
///
/// clock.advance(const Duration(minutes: 30));
/// expect(clock.now(), DateTime.utc(2026, 1, 15, 10, 30, 0));
/// ```
class FakeClock implements Clock {
  DateTime _current;

  FakeClock(this._current);

  @override
  DateTime now() => _current;

  /// Advance the clock by [duration].
  void advance(Duration duration) {
    _current = _current.add(duration);
  }

  /// Set the clock to an explicit [time].
  void setTime(DateTime time) {
    _current = time;
  }
}
