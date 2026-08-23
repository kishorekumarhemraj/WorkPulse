import 'package:equatable/equatable.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/repositories/session_repository.dart';
import 'package:workpulse/domain/repositories/work_item_repository.dart';
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
  final WorkItemRepository _workItemRepository;

  TaskSwitchService({
    required TimerService timerService,
    required SessionRepository sessionRepository,
    required WorkItemRepository workItemRepository,
  })  : _timerService = timerService,
        _sessionRepository = sessionRepository,
        _workItemRepository = workItemRepository;

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
      throw const ValidationException(
          'No active session found to switch from.');
    }

    if (activeSession.workItemId != currentWorkItem.id) {
      throw ValidationException(
        'Active session work item (${activeSession.workItemId}) does not match current work item (${currentWorkItem.id}).',
      );
    }

    // 2. Stop current active session with end timestamp
    final stoppedSession = await _timerService.stopSession(
      activeSession.id,
      endTime: effectiveSwitchTime,
    );

    // If closing notes are provided, update previous work item notes in SQLite
    if (currentSessionNotes != null && currentSessionNotes.trim().isNotEmpty) {
      final note = currentSessionNotes.trim();
      final currentNotes = currentWorkItem.notes;
      final updatedNotes = (currentNotes == null || currentNotes.isEmpty)
          ? note
          : '$currentNotes\n---\n$note';
      await _workItemRepository
          .update(currentWorkItem.copyWith(notes: updatedNotes));
    }

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
