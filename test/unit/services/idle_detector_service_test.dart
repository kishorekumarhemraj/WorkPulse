import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/platform/idle_detector_service.dart';
import 'package:workpulse/core/platform/system_idle_source.dart';

void main() {
  group('DesktopIdleDetectorService', () {
    late FakeIdleSource source;
    late DesktopIdleDetectorService detector;
    late List<IdleDetectionEvent> events;
    late StreamSubscription<IdleDetectionEvent> subscription;
    late List<_FakeTimer> timers;
    late DateTime clock;

    setUp(() {
      source = FakeIdleSource(current: Duration.zero);
      timers = [];
      // Pinned so a stretch's start and end can be asserted exactly rather
      // than to the nearest microsecond of real time.
      clock = DateTime.utc(2026, 8, 27, 12, 0);
      detector = DesktopIdleDetectorService(
        initialThreshold: const Duration(minutes: 10),
        idleSource: source,
        clock: () => clock,
        timerFactory: (duration, callback) {
          final timer = _FakeTimer(duration);
          timers.add(timer);
          return timer;
        },
      );
      events = [];
      subscription = detector.onIdleDetected.listen(events.add);
    });

    tearDown(() async {
      await subscription.cancel();
      detector.dispose();
    });

    test('does not fire while system idle time is below the threshold',
        () async {
      detector.startMonitoring(isTracking: true);
      source.current = const Duration(minutes: 9, seconds: 59);
      detector.poll();
      await _flush();

      expect(events, isEmpty);
    });

    test('fires once the threshold is crossed', () async {
      detector.startMonitoring(isTracking: true);
      source.current = const Duration(minutes: 12);
      detector.poll();
      await _flush();

      expect(events, hasLength(1));
      expect(events.single.idleDuration, const Duration(minutes: 12));
      expect(events.single.trigger, IdleTrigger.inactivity);
      expect(
        events.single.idleEndTime.difference(events.single.idleStartTime),
        const Duration(minutes: 12),
      );
    });

    test('reports the whole absence, not the threshold that noticed it',
        () async {
      // The bug this pins: a 30-minute lunch on a 10-minute threshold was
      // offered to the user as ten minutes, because the stretch was reported
      // once at the crossing and never updated.
      detector.startMonitoring(isTracking: true);

      source.current = const Duration(minutes: 10);
      detector.poll();

      clock = clock.add(const Duration(minutes: 20));
      source.current = const Duration(minutes: 30);
      detector.poll();
      await _flush();

      expect(events, hasLength(2));
      expect(events.last.idleDuration, const Duration(minutes: 30));
      // Same stretch throughout, which is how a listener tells an update
      // from a new question.
      expect(events.last.idleStartTime, events.first.idleStartTime);
    });

    test('pins the end to the moment input resumed, not the moment noticed',
        () async {
      detector.startMonitoring(isTracking: true);

      final away = clock;
      source.current = const Duration(minutes: 10);
      detector.poll();

      // The user came back at +30m. The poll notices 5 seconds later, by
      // which time the OS counter has reset to 5 seconds.
      clock = clock.add(const Duration(minutes: 30, seconds: 5));
      source.current = const Duration(seconds: 5);
      detector.poll();
      await _flush();

      final resumed = events.last;
      expect(resumed.idleStartTime, away.subtract(const Duration(minutes: 10)));
      expect(resumed.idleEndTime, clock.subtract(const Duration(seconds: 5)));
      expect(resumed.idleDuration, const Duration(minutes: 40));
    });

    test('treats a fresh stretch as a new question, not a continuation',
        () async {
      detector.startMonitoring(isTracking: true);
      source.current = const Duration(minutes: 12);
      detector.poll();
      await _flush();
      final first = events.last.idleStartTime;

      // Input resumed: the OS counter resets.
      clock = clock.add(const Duration(minutes: 1));
      source.current = const Duration(seconds: 2);
      detector.poll();

      clock = clock.add(const Duration(minutes: 11));
      source.current = const Duration(minutes: 11);
      detector.poll();
      await _flush();

      expect(events.last.idleStartTime, isNot(first));
      expect(events.last.idleDuration, const Duration(minutes: 11));
    });

    test('stays quiet while input keeps arriving', () async {
      detector.startMonitoring(isTracking: true);
      source.current = const Duration(seconds: 30);
      detector.poll();
      clock = clock.add(const Duration(seconds: 10));
      detector.poll();
      await _flush();

      // Nothing crossed the threshold, so there is no stretch to close.
      expect(events, isEmpty);
    });

    test('never fires while no session is being tracked', () async {
      source.current = const Duration(hours: 3);
      detector.poll();
      await _flush();

      expect(events, isEmpty);
    });

    // Regression: the shell listens to the timer provider, which republishes
    // once a second. Restarting on every one of those calls destroyed the poll
    // timer before it could ever fire.
    test('repeated startMonitoring(true) does not restart the poll timer', () {
      detector.startMonitoring(isTracking: true);
      expect(timers, hasLength(1));

      for (var i = 0; i < 30; i++) {
        detector.startMonitoring(isTracking: true);
      }

      expect(timers, hasLength(1));
      expect(timers.single.isCancelled, isFalse);
    });

    test('stops polling when tracking ends and restarts when it resumes', () {
      detector.startMonitoring(isTracking: true);
      detector.startMonitoring(isTracking: false);

      expect(timers.single.isCancelled, isTrue);

      detector.startMonitoring(isTracking: true);
      expect(timers, hasLength(2));
      expect(timers.last.isCancelled, isFalse);
    });

    test('an unsupported platform never raises events and starts no timer',
        () async {
      final unsupported = DesktopIdleDetectorService(
        idleSource: FakeIdleSource(isAvailable: false),
        timerFactory: (duration, callback) {
          final timer = _FakeTimer(duration);
          timers.add(timer);
          return timer;
        },
      );
      addTearDown(unsupported.dispose);

      final raised = <IdleDetectionEvent>[];
      final sub = unsupported.onIdleDetected.listen(raised.add);
      addTearDown(sub.cancel);

      unsupported.startMonitoring(isTracking: true);
      unsupported.poll();
      await _flush();

      expect(unsupported.isSupported, isFalse);
      expect(timers, isEmpty);
      expect(raised, isEmpty);
    });

    test('a source that cannot answer this poll is treated as no answer',
        () async {
      detector.startMonitoring(isTracking: true);
      source.current = null;
      detector.poll();
      await _flush();

      expect(events, isEmpty);
    });

    test('setIdleThreshold takes effect on the next poll', () async {
      detector.startMonitoring(isTracking: true);
      source.current = const Duration(minutes: 4);
      detector.poll();
      await _flush();
      expect(events, isEmpty);

      detector.setIdleThreshold(const Duration(minutes: 3));
      detector.poll();
      await _flush();
      expect(events, hasLength(1));
    });

    test('defaults to the threshold the spec calls for', () {
      expect(
        DesktopIdleDetectorService.defaultIdleThreshold,
        const Duration(minutes: 10),
      );
    });
  });

  group('MacOsIdleSource.secondsToDuration', () {
    test('converts seconds to a Duration', () {
      expect(
        MacOsIdleSource.secondsToDuration(12.5),
        const Duration(seconds: 12, milliseconds: 500),
      );
    });

    test('rejects values that mean "no answer"', () {
      expect(MacOsIdleSource.secondsToDuration(double.nan), isNull);
      expect(MacOsIdleSource.secondsToDuration(double.infinity), isNull);
      expect(MacOsIdleSource.secondsToDuration(-1), isNull);
    });
  });

  group('WindowsIdleSource.ticksToDuration', () {
    test('subtracts tick counts', () {
      expect(
        WindowsIdleSource.ticksToDuration(
          lastInputTick: 1000,
          currentTick: 61000,
        ),
        const Duration(seconds: 60),
      );
    });

    // GetTickCount is a 32-bit millisecond counter that wraps every ~49.7 days.
    test('handles the 32-bit tick counter wrapping', () {
      expect(
        WindowsIdleSource.ticksToDuration(
          lastInputTick: 0xFFFFFFFF - 999,
          currentTick: 1000,
        ),
        const Duration(seconds: 2),
      );
    });
  });

  group('UnavailableIdleSource', () {
    test('reports nothing and stays unavailable', () {
      const source = UnavailableIdleSource();
      expect(source.isAvailable, isFalse);
      expect(source.idleTime(), isNull);
    });
  });
}

/// Lets the broadcast stream deliver everything queued by the polls above.
Future<void> _flush() => Future<void>.delayed(Duration.zero);

/// A [Timer] stand-in so the detector's lifecycle can be asserted without
/// waiting on wall-clock time.
class _FakeTimer implements Timer {
  final Duration duration;
  bool isCancelled = false;

  _FakeTimer(this.duration);

  @override
  void cancel() => isCancelled = true;

  @override
  bool get isActive => !isCancelled;

  @override
  int get tick => 0;
}
