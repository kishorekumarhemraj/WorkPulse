import 'package:uuid/uuid.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/repositories/session_repository.dart';
import 'package:workpulse/domain/repositories/work_item_repository.dart';

const _uuid = Uuid();

class TimerService {
  final SessionRepository _sessionRepository;
  final WorkItemRepository _workItemRepository;

  TimerService({
    required SessionRepository sessionRepository,
    required WorkItemRepository workItemRepository,
  })  : _sessionRepository = sessionRepository,
        _workItemRepository = workItemRepository;

  /// Returns the currently running session, if any.
  Future<Session?> getActiveSession() async {
    return _sessionRepository.getActiveSession();
  }

  /// Starts tracking time on a work item.
  /// Enforces the Single-Active-Session invariant: stops any currently running session.
  Future<Session> startSession(
    String workItemId, {
    String? categoryId,
    List<String> tagIds = const [],
    List<String> peopleIds = const [],
    String? notes,
    DateTime? startTime,
  }) async {
    final now = DateTime.now().toUtc();
    final effectiveStartTime = startTime ?? now;

    // Enforce single-active-session invariant: close any active session first
    final active = await _sessionRepository.getActiveSession();
    if (active != null) {
      final stopped = active.copyWith(endTime: effectiveStartTime);
      await _sessionRepository.update(stopped);
    }

    // Create new session
    final newSession = Session(
      id: _uuid.v4(),
      workItemId: workItemId,
      categoryId: categoryId,
      startTime: effectiveStartTime,
      tagIds: tagIds,
      peopleIds: peopleIds,
      notes: notes,
      createdAt: now,
    );

    final created = await _sessionRepository.create(newSession);

    // Update last_worked_at timestamp on the work item
    await _workItemRepository.updateLastWorkedAt(workItemId, effectiveStartTime);

    return created;
  }

  /// Updates the category of a session.
  Future<Session?> updateSessionCategory(String sessionId, String? categoryId) async {
    final session = await _sessionRepository.getById(sessionId);
    if (session == null) return null;
    final updated = session.copyWith(categoryId: categoryId, clearCategory: categoryId == null);
    return _sessionRepository.update(updated);
  }

  /// Updates the tags of a session.
  Future<Session?> updateSessionTags(String sessionId, List<String> tagIds) async {
    final session = await _sessionRepository.getById(sessionId);
    if (session == null) return null;
    final updated = session.copyWith(tagIds: tagIds);
    return _sessionRepository.update(updated);
  }

  /// Updates the people associated with a session.
  Future<Session?> updateSessionPeople(String sessionId, List<String> peopleIds) async {
    final session = await _sessionRepository.getById(sessionId);
    if (session == null) return null;
    final updated = session.copyWith(peopleIds: peopleIds);
    return _sessionRepository.update(updated);
  }

  /// Updates the notes of a session.
  Future<Session?> updateSessionNotes(String sessionId, String? notes) async {
    final session = await _sessionRepository.getById(sessionId);
    if (session == null) return null;
    final updated = session.copyWith(notes: notes, clearNotes: notes == null);
    return _sessionRepository.update(updated);
  }

  /// Stops an active session.
  Future<Session> stopSession(String sessionId, {DateTime? endTime}) async {
    final session = await _sessionRepository.getById(sessionId);
    if (session == null) {
      throw NotFoundException('Session with id $sessionId not found');
    }

    if (session.endTime != null) {
      return session; // Already stopped
    }

    final stopped = session.copyWith(
      endTime: endTime ?? DateTime.now().toUtc(),
    );

    return _sessionRepository.update(stopped);
  }

  /// Computes total accumulated duration across all historical and active sessions for a work item.
  Future<Duration> getWorkItemTotalDuration(
    String workItemId, {
    Session? activeSession,
  }) async {
    final historicalSessions = await _sessionRepository.getByWorkItemId(workItemId);

    var totalMicroseconds = 0;
    var activeIncluded = false;

    for (final s in historicalSessions) {
      if (activeSession != null && s.id == activeSession.id) {
        totalMicroseconds += activeSession.duration.inMicroseconds;
        activeIncluded = true;
      } else {
        totalMicroseconds += s.duration.inMicroseconds;
      }
    }

    if (activeSession != null && activeSession.workItemId == workItemId && !activeIncluded) {
      totalMicroseconds += activeSession.duration.inMicroseconds;
    }

    return Duration(microseconds: totalMicroseconds);
  }

  /// Formats duration into a readable string format.
  /// Standard: `HH:MM:SS` (e.g. `01:23:45`) or `MM:SS` (e.g. `05:12`)
  /// Compact: `1h 23m` or `5m 12s` or `45s`
  static String formatDuration(Duration duration, {bool compact = false, bool includeSeconds = true}) {
    if (duration.isNegative) {
      return '00:00';
    }

    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (compact) {
      if (hours > 0) {
        return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
      }
      if (minutes > 0) {
        return includeSeconds && seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
      }
      return '${seconds}s';
    }

    final hoursStr = hours.toString().padLeft(2, '0');
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');

    if (!includeSeconds) {
      return '$hoursStr:$minutesStr';
    }
    return '$hoursStr:$minutesStr:$secondsStr';
  }
}
