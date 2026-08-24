import 'dart:async';

import 'package:workpulse/domain/repositories/settings_repository.dart';

/// Persists a "WorkPulse was alive at this moment" timestamp so a gap between
/// two runs can be reconstructed after the process is gone.
///
/// The live idle detector only ever sees time that elapses while the process is
/// running: quitting WorkPulse, logging out, or shutting the Mac down kills its
/// polling timer, and the next launch starts with a blank slate. A heartbeat in
/// SQLite is what survives that, and lets startup tell "8 hours of work" apart
/// from "8 hours during which the app was not running".
class ActivityHeartbeatService {
  /// Settings key holding the last heartbeat as an ISO-8601 UTC string.
  static const String settingsKey = 'last_activity_heartbeat_at';

  /// How often the heartbeat is refreshed while a session runs. Also the
  /// worst-case error on a detected gap's start time, so it is kept well below
  /// the smallest sensible idle threshold.
  static const Duration defaultInterval = Duration(seconds: 30);

  final SettingsRepository _settingsRepository;
  final Duration interval;
  final DateTime Function() _clock;

  Timer? _timer;

  ActivityHeartbeatService({
    required SettingsRepository settingsRepository,
    this.interval = defaultInterval,
    DateTime Function()? clock,
  })  : _settingsRepository = settingsRepository,
        _clock = clock ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  bool get isBeating => _timer != null;

  /// The last recorded heartbeat, or null when none was ever written (fresh
  /// install, or an install that predates heartbeats).
  Future<DateTime?> readLastHeartbeat() async {
    final raw = await _settingsRepository.getSetting(settingsKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  /// Records "alive right now". Called on the interval, when the app changes
  /// lifecycle state, and whenever an idle prompt is resolved.
  Future<void> beat() async {
    await _settingsRepository.setSetting(
      settingsKey,
      _clock().toIso8601String(),
    );
  }

  Future<void> clear() => _settingsRepository.removeSetting(settingsKey);

  /// Begins beating, writing one immediately so a crash seconds later still
  /// leaves an accurate mark. Idempotent.
  void start() {
    if (_timer != null) return;
    unawaited(_safeBeat());
    _timer = Timer.periodic(interval, (_) => unawaited(_safeBeat()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();

  /// A failed write only costs precision on the next gap calculation, so it
  /// must never surface as an unhandled error out of the periodic timer.
  Future<void> _safeBeat() async {
    try {
      await beat();
    } catch (_) {
      // Intentionally swallowed: see doc comment.
    }
  }
}
