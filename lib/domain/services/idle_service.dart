import 'package:uuid/uuid.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/repositories/idle_period_repository.dart';
import 'package:workpulse/domain/repositories/session_repository.dart';
import 'package:workpulse/domain/services/timer_service.dart';

const _uuid = Uuid();

class IdleResolutionResult {
  final IdlePeriod idlePeriod;
  final Session? stoppedSession;
  final Session? newSession;

  const IdleResolutionResult({
    required this.idlePeriod,
    this.stoppedSession,
    this.newSession,
  });
}

class IdleService {
  final SessionRepository _sessionRepository;
  final IdlePeriodRepository _idlePeriodRepository;
  final TimerService _timerService;

  IdleService({
    required SessionRepository sessionRepository,
    required IdlePeriodRepository idlePeriodRepository,
    required TimerService timerService,
  })  : _sessionRepository = sessionRepository,
        _idlePeriodRepository = idlePeriodRepository,
        _timerService = timerService;

  /// Option 1: Keep Tracking — counts the idle duration as active work on current task.
  Future<IdleResolutionResult> resolveKeepTracking({
    required String sessionId,
    required DateTime idleStartTime,
    required DateTime idleEndTime,
  }) async {
    final session = await _sessionRepository.getById(sessionId);
    if (session == null) {
      throw NotFoundException('Session with id $sessionId not found');
    }

    final idlePeriod = IdlePeriod(
      id: _uuid.v4(),
      sessionId: sessionId,
      startTime: idleStartTime,
      endTime: idleEndTime,
      resolution: IdleResolution.keepTracking,
      createdAt: DateTime.now().toUtc(),
    );

    await _idlePeriodRepository.createIdlePeriod(idlePeriod);

    return IdleResolutionResult(idlePeriod: idlePeriod);
  }

  /// Option 2: Mark Idle — discards the idle duration by ending the current session
  /// at [idleStartTime], and starts a fresh new session for the work item at [idleEndTime].
  Future<IdleResolutionResult> resolveMarkIdle({
    required String sessionId,
    required String workItemId,
    required DateTime idleStartTime,
    required DateTime idleEndTime,
    List<String> peopleIds = const [],
  }) async {
    final session = await _sessionRepository.getById(sessionId);
    if (session == null) {
      throw NotFoundException('Session with id $sessionId not found');
    }

    // 1. Stop current session at the moment user went idle
    final stoppedSession = await _timerService.stopSession(
      sessionId,
      endTime: idleStartTime,
    );

    // 2. Record the idle period in SQLite
    final idlePeriod = IdlePeriod(
      id: _uuid.v4(),
      sessionId: sessionId,
      startTime: idleStartTime,
      endTime: idleEndTime,
      resolution: IdleResolution.markIdle,
      createdAt: DateTime.now().toUtc(),
    );
    await _idlePeriodRepository.createIdlePeriod(idlePeriod);

    // 3. Start a new session starting now (at idleEndTime)
    final newSession = await _timerService.startSession(
      workItemId,
      startTime: idleEndTime,
      peopleIds: peopleIds.isNotEmpty ? peopleIds : session.peopleIds,
    );

    return IdleResolutionResult(
      idlePeriod: idlePeriod,
      stoppedSession: stoppedSession,
      newSession: newSession,
    );
  }

  /// Option 3: Stop Session — stops tracking as of when inactivity began [idleStartTime].
  Future<IdleResolutionResult> resolveStopSession({
    required String sessionId,
    required DateTime idleStartTime,
    required DateTime idleEndTime,
  }) async {
    final session = await _sessionRepository.getById(sessionId);
    if (session == null) {
      throw NotFoundException('Session with id $sessionId not found');
    }

    // 1. Stop current session at idle start timestamp
    final stoppedSession = await _timerService.stopSession(
      sessionId,
      endTime: idleStartTime,
    );

    // 2. Record the idle period in SQLite
    final idlePeriod = IdlePeriod(
      id: _uuid.v4(),
      sessionId: sessionId,
      startTime: idleStartTime,
      endTime: idleEndTime,
      resolution: IdleResolution.stopSession,
      createdAt: DateTime.now().toUtc(),
    );
    await _idlePeriodRepository.createIdlePeriod(idlePeriod);

    return IdleResolutionResult(
      idlePeriod: idlePeriod,
      stoppedSession: stoppedSession,
    );
  }
}
