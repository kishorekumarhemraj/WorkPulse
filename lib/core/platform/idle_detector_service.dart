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

  /// Set when an event has been raised for the current stretch of inactivity,
  /// and cleared once input resumes. Without it the poll would re-raise every
  /// [pollInterval] for as long as the user stayed away.
  bool _hasReportedCurrentIdle = false;

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

    _hasReportedCurrentIdle = false;

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

    if (idleFor < _idleThreshold) {
      // Input has resumed, so the next stretch of inactivity is a new event.
      _hasReportedCurrentIdle = false;
      return;
    }

    if (_hasReportedCurrentIdle) return;
    _hasReportedCurrentIdle = true;

    final now = _clock();
    _controller.add(
      IdleDetectionEvent(
        idleDuration: idleFor,
        idleStartTime: now.subtract(idleFor),
        idleEndTime: now,
      ),
    );
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _hasReportedCurrentIdle = false;
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
