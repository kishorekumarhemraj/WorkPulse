import 'dart:async';
import 'package:equatable/equatable.dart';

class IdleDetectionEvent extends Equatable {
  final Duration idleDuration;
  final DateTime idleStartTime;
  final DateTime idleEndTime;

  const IdleDetectionEvent({
    required this.idleDuration,
    required this.idleStartTime,
    required this.idleEndTime,
  });

  @override
  List<Object?> get props => [idleDuration, idleStartTime, idleEndTime];
}

abstract class IdleDetectorService {
  Duration get idleThreshold;
  void setIdleThreshold(Duration duration);
  Stream<IdleDetectionEvent> get onIdleDetected;
  void startMonitoring({required bool isTracking});
  void stopMonitoring();
  void simulateIdle({required Duration duration, DateTime? startTime});
  void dispose();
}

class DesktopIdleDetectorService implements IdleDetectorService {
  Duration _idleThreshold = const Duration(minutes: 5);
  final _controller = StreamController<IdleDetectionEvent>.broadcast();
  Timer? _pollingTimer;
  bool _isTracking = false;
  DateTime _lastActivityTime = DateTime.now().toUtc();

  DesktopIdleDetectorService({Duration? initialThreshold}) {
    if (initialThreshold != null) {
      _idleThreshold = initialThreshold;
    }
  }

  @override
  Duration get idleThreshold => _idleThreshold;

  @override
  void setIdleThreshold(Duration duration) {
    _idleThreshold = duration;
  }

  @override
  Stream<IdleDetectionEvent> get onIdleDetected => _controller.stream;

  void recordUserActivity() {
    _lastActivityTime = DateTime.now().toUtc();
  }

  @override
  void startMonitoring({required bool isTracking}) {
    _isTracking = isTracking;
    _pollingTimer?.cancel();

    if (!_isTracking) return;

    _lastActivityTime = DateTime.now().toUtc();

    // Check every 10 seconds if elapsed time since last activity exceeds threshold
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isTracking) return;

      final now = DateTime.now().toUtc();
      final elapsedSinceActivity = now.difference(_lastActivityTime);

      if (elapsedSinceActivity >= _idleThreshold) {
        final idleEvent = IdleDetectionEvent(
          idleDuration: elapsedSinceActivity,
          idleStartTime: _lastActivityTime,
          idleEndTime: now,
        );
        _controller.add(idleEvent);
        // Reset last activity to avoid continuous repeated spam while prompt is open
        _lastActivityTime = now;
      }
    });
  }

  @override
  void stopMonitoring() {
    _isTracking = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void simulateIdle({required Duration duration, DateTime? startTime}) {
    final end = DateTime.now().toUtc();
    final start = startTime ?? end.subtract(duration);
    _controller.add(IdleDetectionEvent(
      idleDuration: duration,
      idleStartTime: start,
      idleEndTime: end,
    ));
  }

  @override
  void dispose() {
    stopMonitoring();
    _controller.close();
  }
}
