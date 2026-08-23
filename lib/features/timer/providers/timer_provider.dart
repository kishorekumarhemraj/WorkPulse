import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/task_switch_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/timer/models/timer_state.dart';

final timerServiceProvider = Provider<TimerService>((ref) {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final workItemRepo = ref.watch(workItemRepositoryProvider);
  return TimerService(
    sessionRepository: sessionRepo,
    workItemRepository: workItemRepo,
  );
});

final taskSwitchServiceProvider = Provider<TaskSwitchService>((ref) {
  return TaskSwitchService(
    timerService: ref.watch(timerServiceProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
  );
});

final timerProvider = AsyncNotifierProvider<TimerNotifier, TimerState>(
  TimerNotifier.new,
);

class TimerNotifier extends AsyncNotifier<TimerState> {
  Timer? _ticker;

  @override
  Future<TimerState> build() async {
    ref.onDispose(() {
      _ticker?.cancel();
    });

    final timerService = ref.watch(timerServiceProvider);
    final workItemRepo = ref.watch(workItemRepositoryProvider);

    // Startup / Crash / Sleep recovery: check if an active session exists
    final activeSession = await timerService.getActiveSession();
    if (activeSession != null) {
      final workItem = await workItemRepo.getById(activeSession.workItemId);
      final elapsed = DateTime.now().toUtc().difference(activeSession.startTime);

      _startTicker(activeSession.startTime);

      return TimerState(
        status: TimerStatus.running,
        activeWorkItem: workItem,
        activeSession: activeSession,
        elapsed: elapsed,
      );
    }

    return const TimerState(status: TimerStatus.idle);
  }

  void _startTicker(DateTime startTime) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final currentState = state.value;
      if (currentState != null && currentState.status != TimerStatus.idle) {
        final currentElapsed = DateTime.now().toUtc().difference(startTime);
        state = AsyncData(currentState.copyWith(elapsed: currentElapsed));
      }
    });
  }

  /// Starts tracking time on a work item.
  Future<void> startTimer(
    WorkItem workItem, {
    List<String> peopleIds = const [],
  }) async {
    final current = state.value;

    // If already tracking this exact work item, do nothing
    if (current != null && current.isRunning && current.activeWorkItem?.id == workItem.id) {
      return;
    }

    // If currently tracking another work item, trigger switch confirmation
    if (current != null && current.isRunning && current.activeWorkItem?.id != workItem.id) {
      requestSwitch(workItem);
      return;
    }

    final timerService = ref.read(timerServiceProvider);
    final now = DateTime.now().toUtc();

    final newSession = await timerService.startSession(
      workItem.id,
      peopleIds: peopleIds,
      startTime: now,
    );

    _startTicker(newSession.startTime);

    state = AsyncData(
      TimerState(
        status: TimerStatus.running,
        activeWorkItem: workItem,
        activeSession: newSession,
        elapsed: Duration.zero,
      ),
    );

    ref.invalidate(workItemsProvider);
  }

  /// Stops tracking the active session.
  Future<Session?> stopTimer() async {
    final current = state.value;
    if (current == null || !current.isRunning || current.activeSession == null) {
      return null;
    }

    _ticker?.cancel();
    _ticker = null;

    final timerService = ref.read(timerServiceProvider);
    final stoppedSession = await timerService.stopSession(current.activeSession!.id);

    state = const AsyncData(TimerState(status: TimerStatus.idle));
    ref.invalidate(workItemsProvider);

    return stoppedSession;
  }

  /// Initiates a task switch request.
  void requestSwitch(WorkItem targetWorkItem) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        status: TimerStatus.switching,
        pendingSwitchWorkItem: targetWorkItem,
      ),
    );
  }

  /// Confirms and executes switching from active task to pending task with optional session note.
  Future<void> confirmSwitch({String? notes}) async {
    final current = state.value;
    if (current == null || current.pendingSwitchWorkItem == null) return;

    final targetWorkItem = current.pendingSwitchWorkItem!;
    final now = DateTime.now().toUtc();

    if (current.activeWorkItem != null && current.activeSession != null) {
      final switchService = ref.read(taskSwitchServiceProvider);
      final result = await switchService.switchTask(
        currentWorkItem: current.activeWorkItem!,
        targetWorkItem: targetWorkItem,
        currentSessionNotes: notes,
        switchTime: now,
      );

      _startTicker(result.startedSession.startTime);

      state = AsyncData(
        TimerState(
          status: TimerStatus.running,
          activeWorkItem: targetWorkItem,
          activeSession: result.startedSession,
          elapsed: Duration.zero,
        ),
      );
    } else {
      final timerService = ref.read(timerServiceProvider);
      final newSession = await timerService.startSession(
        targetWorkItem.id,
        startTime: now,
      );

      _startTicker(newSession.startTime);

      state = AsyncData(
        TimerState(
          status: TimerStatus.running,
          activeWorkItem: targetWorkItem,
          activeSession: newSession,
          elapsed: Duration.zero,
        ),
      );
    }

    ref.invalidate(workItemsProvider);
  }

  /// Cancels the task switch request, resuming current timer view.
  void cancelSwitch() {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        status: TimerStatus.running,
        clearPendingSwitchWorkItem: true,
      ),
    );
  }
}
