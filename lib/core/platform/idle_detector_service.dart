import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:workpulse/core/platform/system_idle_source.dart';

/// What produced an [IdleDetectionEvent]. The two cases are detected by
/// completely different means and read very differently to the user, so the
/// prompt words itself from this.
enum IdleTrigger {
  /// No activity for longer than the threshold while WorkPulse was running.
  inactivity,

  /// Wall-clock time a still-open session covers but WorkPulse was not running
  /// for: the app was quit, the user logged out, or the Mac was shut down.
  /// Reconstructed at startup from the persisted activity heartbeat.
  appNotRunning,
}

class IdleDetectionEvent extends Equatable {
  final Duration idleDuration;
  final DateTime idleStartTime;
  final DateTime idleEndTime;
  final IdleTrigger trigger;

  const IdleDetectionEvent({
    required this.idleDuration,
    required this.idleStartTime,
    required this.idleEndTime,
    this.trigger = IdleTrigger.inactivity,
  });

  @override
  List<Object?> get props =>
      [idleDuration, idleStartTime, idleEndTime, trigger];
}

abstract class IdleDetectorService {
  Duration get idleThreshold;
  void setIdleThreshold(Duration duration);
  Stream<IdleDetectionEvent> get onIdleDetected;

  /// Whether this detector can observe real system input. When false the
  /// detector never raises [onIdleDetected] on its own; startup gap recovery
  /// from the persisted heartbeat still works.
  bool get isSupported;

  void startMonitoring({required bool isTracking});
  void stopMonitoring();
  void dispose();
}

/// Polls the operating system's own "time since last input" counter and raises
/// an event once it crosses [idleThreshold].
///
/// Two things matter about the shape of this class.
///
/// **It asks the OS rather than tracking activity itself.** WorkPulse's whole
/// purpose is to keep running while the user works in *other* applications, so
/// activity observed inside its own window is not the question being asked —
/// see [SystemIdleSource].
///
/// **[startMonitoring] is idempotent.** It is called from a `ref.listen` on the
/// timer, which emits once a second while a session runs. Restarting the poll
/// timer on each of those calls meant the 10-second timer was destroyed before
/// it ever fired, so live idle detection never triggered at all.
///
/// **A stretch of inactivity is reported until it ends, not once when it
/// starts.** The threshold says when to start caring, not how long the user
/// was away: reporting once at the crossing meant a 30-minute lunch was
/// offered to the user as three minutes, and "Mark as Idle & Resume" then
/// restarted the timer 27 minutes in the past and booked the absence as work.
/// Each poll re-reports the same stretch with its span so far, and the poll
/// that sees input resume pins the end to the moment it actually resumed.
/// Every report of one stretch carries the same [IdleDetectionEvent.
/// idleStartTime], which is what lets a listener tell an update from a new
/// stretch.
class DesktopIdleDetectorService implements IdleDetectorService {
  /// The spec's default (`docs/WORKPULSE_SPEC.md` §31).
  static const Duration defaultIdleThreshold = Duration(minutes: 10);

  /// How often the OS counter is sampled. The query itself is a cheap native
  /// call, and this bounds how late a crossing is noticed.
  static const Duration pollInterval = Duration(seconds: 10);

  final SystemIdleSource _idleSource;
  final DateTime Function() _clock;

  Duration _idleThreshold;
  final _controller = StreamController<IdleDetectionEvent>.broadcast();
  Timer? _pollingTimer;
  bool _isTracking = false;

  /// When the current reported stretch of inactivity began, or null if the
  /// user is not currently past the threshold.
  ///
  /// Computed once, at the crossing, and reused for every later report of the
  /// same stretch. Recomputing it per poll would let clock and OS-counter
  /// jitter move it by a second or two each time, and listeners identify a
  /// stretch by this value.
  DateTime? _currentIdleStart;

  DesktopIdleDetectorService({
    Duration? initialThreshold,
    SystemIdleSource? idleSource,
    DateTime Function()? clock,
    Timer Function(Duration, void Function(Timer))? timerFactory,
  })  : _idleThreshold = initialThreshold ?? defaultIdleThreshold,
        _idleSource = idleSource ?? SystemIdleSource.forPlatform(),
        _clock = clock ?? _utcNow,
        _timerFactory = timerFactory ?? Timer.periodic;

  final Timer Function(Duration, void Function(Timer)) _timerFactory;

  static DateTime _utcNow() => DateTime.now().toUtc();

  @override
  Duration get idleThreshold => _idleThreshold;

  @override
  bool get isSupported => _idleSource.isAvailable;

  @override
  void setIdleThreshold(Duration duration) {
    _idleThreshold = duration;
  }

  @override
  Stream<IdleDetectionEvent> get onIdleDetected => _controller.stream;

  @override
  void startMonitoring({required bool isTracking}) {
    // Idempotent by design: see the class doc comment.
    if (isTracking == _isTracking) return;

    _isTracking = isTracking;

    if (!isTracking) {
      _stopPolling();
      return;
    }

    _currentIdleStart = null;

    if (!_idleSource.isAvailable) {
      // Degrade loudly rather than pretending to watch. Startup gap recovery
      // still covers time the app was not running.
      debugPrint(
        '[WorkPulse] Live idle detection is unavailable on this platform; '
        'only unaccounted-time recovery at startup will run.',
      );
      return;
    }

    _pollingTimer = _timerFactory(pollInterval, (_) => poll());
  }

  /// One sampling pass. Exposed so tests can advance the detector without
  /// waiting on a real timer.
  @visibleForTesting
  void poll() {
    if (!_isTracking) return;

    final idleFor = _idleSource.idleTime();
    if (idleFor == null) return;

    final now = _clock();

    if (idleFor < _idleThreshold) {
      final start = _currentIdleStart;
      if (start != null) {
        // Input resumed. The OS counter reset when the user touched the
        // machine, so `now - idleFor` is the moment they came back — which is
        // the real end of the stretch, and the only figure that makes
        // "resume from now" resume from now.
        _currentIdleStart = null;
        _emit(start, now.subtract(idleFor));
      }
      return;
    }

    // Still away. Re-report the same stretch, grown, so a listener that is
    // already showing it is never more than one poll out of date.
    final start = _currentIdleStart ??= now.subtract(idleFor);
    _emit(start, now);
  }

  void _emit(DateTime start, DateTime end) {
    // A pinned end can land marginally before the start when the OS counter
    // and the clock disagree at the edges; report nothing rather than a
    // negative stretch.
    if (!end.isAfter(start)) return;

    _controller.add(
      IdleDetectionEvent(
        idleDuration: end.difference(start),
        idleStartTime: start,
        idleEndTime: end,
      ),
    );
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _currentIdleStart = null;
  }

  @override
  void stopMonitoring() {
    _isTracking = false;
    _stopPolling();
  }

  @override
  void dispose() {
    stopMonitoring();
    _idleSource.dispose();
    _controller.close();
  }
}
