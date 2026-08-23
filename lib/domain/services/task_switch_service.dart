import 'package:equatable/equatable.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/repositories/session_repository.dart';
import 'package:workpulse/domain/services/timer_service.dart';

class TaskSwitchResult extends Equatable {
  final Session stoppedSession;
  final Session startedSession;
  final WorkItem previousWorkItem;
  final WorkItem newWorkItem;
  final Duration previousSessionDuration;

  const TaskSwitchResult({
    required this.stoppedSession,
    required this.startedSession,
    required this.previousWorkItem,
    required this.newWorkItem,
    required this.previousSessionDuration,
  });

  @override
  List<Object?> get props => [
        stoppedSession,
        startedSession,
        previousWorkItem,
        newWorkItem,
        previousSessionDuration,
      ];
}

class TaskSwitchService {
  final TimerService _timerService;
  final SessionRepository _sessionRepository;

  TaskSwitchService({
    required TimerService timerService,
    required SessionRepository sessionRepository,
  })  : _timerService = timerService,
        _sessionRepository = sessionRepository;

  /// Atomically transitions time tracking from [currentWorkItem] to [targetWorkItem].
  Future<TaskSwitchResult> switchTask({
    required WorkItem currentWorkItem,
    required WorkItem targetWorkItem,
    String? currentSessionNotes,
    List<String> targetPeopleIds = const [],
    DateTime? switchTime,
  }) async {
    final effectiveSwitchTime = switchTime ?? DateTime.now().toUtc();

    // 1. Find the active session
    final activeSession = await _sessionRepository.getActiveSession();
    if (activeSession == null) {
      throw ValidationException('No active session found to switch from.');
    }

    if (activeSession.workItemId != currentWorkItem.id) {
      throw ValidationException(
        'Active session work item (${activeSession.workItemId}) does not match current work item (${currentWorkItem.id}).',
      );
    }

    // 2. Stop current active session with closing note and end timestamp
    final stoppedSession = await _timerService.stopSession(
      activeSession.id,
      endTime: effectiveSwitchTime,
      notes: currentSessionNotes,
    );

    // 3. Start new session for target work item starting exactly at effectiveSwitchTime
    final newSession = await _timerService.startSession(
      targetWorkItem.id,
      peopleIds: targetPeopleIds,
      startTime: effectiveSwitchTime,
    );

    return TaskSwitchResult(
      stoppedSession: stoppedSession,
      startedSession: newSession,
      previousWorkItem: currentWorkItem,
      newWorkItem: targetWorkItem,
      previousSessionDuration: stoppedSession.duration,
    );
  }
}
