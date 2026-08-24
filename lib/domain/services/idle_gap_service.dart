import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/repositories/session_repository.dart';
import 'package:workpulse/domain/services/activity_heartbeat_service.dart';

/// A stretch of wall-clock time that an open session claims as work but which
/// WorkPulse has no evidence for, because the app was not running through it.
class UnaccountedGap {
  /// The session still open across the gap.
  final Session session;

  /// The last moment WorkPulse could vouch for — the final heartbeat, or the
  /// session start when no heartbeat covers this session.
  final DateTime startTime;

  /// Now, i.e. the moment the app came back.
  final DateTime endTime;

  const UnaccountedGap({
    required this.session,
    required this.startTime,
    required this.endTime,
  });

  Duration get duration => endTime.difference(startTime);
}

/// Reconstructs, at startup, the time a still-running session accumulated while
/// WorkPulse was not there to watch it.
///
/// This is the counterpart to the live idle detector: that one catches a user
/// sitting still with the app open, this one catches the app being quit or the
/// machine being shut down with the timer left running.
class IdleGapService {
  final SessionRepository _sessionRepository;
  final ActivityHeartbeatService _heartbeatService;

  IdleGapService({
    required SessionRepository sessionRepository,
    required ActivityHeartbeatService heartbeatService,
  })  : _sessionRepository = sessionRepository,
        _heartbeatService = heartbeatService;

  /// Returns the unaccounted gap covering the active session, or null when
  /// there is nothing to ask the user about.
  Future<UnaccountedGap?> detectUnaccountedGap({
    required Duration threshold,
    DateTime? now,
  }) async {
    final session = await _sessionRepository.getActiveSession();
    if (session == null) return null;

    final effectiveNow = (now ?? DateTime.now().toUtc()).toUtc();
    final heartbeat = await _heartbeatService.readLastHeartbeat();

    // A gap can only start once the session itself has started. A heartbeat
    // older than the session start belongs to an earlier run and says nothing
    // about this one; with no heartbeat at all — a fresh install, or one
    // upgrading from a build that never wrote heartbeats — the whole session
    // is unverified, so the session start is the honest lower bound.
    var gapStart = session.startTime.toUtc();
    if (heartbeat != null && heartbeat.isAfter(gapStart)) {
      gapStart = heartbeat;
    }

    // A heartbeat at or after 'now' means the clock moved backwards (timezone
    // correction, NTP step). There is no gap to attribute, so leave the
    // session alone rather than reporting a negative duration.
    if (!gapStart.isBefore(effectiveNow)) return null;

    final gap = effectiveNow.difference(gapStart);
    if (gap < threshold) return null;

    return UnaccountedGap(
      session: session,
      startTime: gapStart,
      endTime: effectiveNow,
    );
  }
}
