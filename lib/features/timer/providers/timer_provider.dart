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
    workItemRepository: ref.watch(workItemRepositoryProvider),
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
      final elapsed =
          DateTime.now().toUtc().difference(activeSession.startTime);

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

  /// Reloads active session from SQLite (e.g. after idle recovery, sleep/wake).
  Future<void> recoverActiveSession() async {
    ref.invalidateSelf();
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
    String? categoryId,
    List<String> tagIds = const [],
    List<String> peopleIds = const [],
    String? notes,
  }) async {
    final current = state.value;

    // If already tracking this exact work item, do nothing
    if (current != null &&
        current.isRunning &&
        current.activeWorkItem?.id == workItem.id) {
      return;
    }

    // If currently tracking another work item, trigger switch confirmation
    if (current != null &&
        current.isRunning &&
        current.activeWorkItem?.id != workItem.id) {
      requestSwitch(workItem);
      return;
    }

    final timerService = ref.read(timerServiceProvider);
    final now = DateTime.now().toUtc();

    // No work-item fallback here: seeding the first session is
    // TimerService's job, so it happens once rather than at every caller.
    final newSession = await timerService.startSession(
      workItem.id,
      categoryId: categoryId,
      tagIds: tagIds,
      peopleIds: peopleIds,
      notes: notes,
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

  /// Updates the category of the currently running session in real-time.
  Future<void> updateActiveSessionCategory(String? categoryId) async {
    final current = state.value;
    if (current == null ||
        !current.isRunning ||
        current.activeSession == null) {
      return;
    }

    final timerService = ref.read(timerServiceProvider);
    final updated = await timerService.updateSessionCategory(
      current.activeSession!.id,
      categoryId,
    );

    if (updated != null) {
      state = AsyncData(
        current.copyWith(activeSession: updated),
      );
      ref.invalidate(workItemsProvider);
    }
  }

  /// Updates the tags of the currently running session in real-time.
  Future<void> updateActiveSessionTags(List<String> tagIds) async {
    final current = state.value;
    if (current == null ||
        !current.isRunning ||
        current.activeSession == null) {
      return;
    }

    final timerService = ref.read(timerServiceProvider);
    final updated = await timerService.updateSessionTags(
      current.activeSession!.id,
      tagIds,
    );

    if (updated != null) {
      state = AsyncData(
        current.copyWith(activeSession: updated),
      );
      ref.invalidate(workItemsProvider);
    }
  }

  /// Updates the assigned people of the currently running session in real-time.
  Future<void> updateActiveSessionPeople(List<String> peopleIds) async {
    final current = state.value;
    if (current == null ||
        !current.isRunning ||
        current.activeSession == null) {
      return;
    }

    final timerService = ref.read(timerServiceProvider);
    final updated = await timerService.updateSessionPeople(
      current.activeSession!.id,
      peopleIds,
    );

    if (updated != null) {
      state = AsyncData(
        current.copyWith(activeSession: updated),
      );
      ref.invalidate(workItemsProvider);
    }
  }

  /// Updates the notes of the currently running session.
  Future<void> updateActiveSessionNotes(String? notes) async {
    final current = state.value;
    if (current == null ||
        !current.isRunning ||
        current.activeSession == null) {
      return;
    }

    final timerService = ref.read(timerServiceProvider);
    final updated = await timerService.updateSessionNotes(
      current.activeSession!.id,
      notes,
    );

    if (updated != null) {
      state = AsyncData(
        current.copyWith(activeSession: updated),
      );
    }
  }

  /// Stops tracking the active session.
  Future<Session?> stopTimer() async {
    final current = state.value;
    if (current == null ||
        !current.isRunning ||
        current.activeSession == null) {
      return null;
    }

    _ticker?.cancel();
    _ticker = null;

    final timerService = ref.read(timerServiceProvider);
    final stoppedSession =
        await timerService.stopSession(current.activeSession!.id);

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
  Future<void> confirmSwitch({
    WorkItem? targetItem,
    String? notes,
    String? targetCategoryId,
    List<String>? targetTagIds,
    List<String>? targetPeopleIds,
  }) async {
    final current = state.value;
    final targetWorkItem = targetItem ?? current?.pendingSwitchWorkItem;
    if (current == null || targetWorkItem == null) return;

    final now = DateTime.now().toUtc();

    if (current.activeWorkItem != null && current.activeSession != null) {
      final switchService = ref.read(taskSwitchServiceProvider);
      final result = await switchService.switchTask(
        currentWorkItem: current.activeWorkItem!,
        targetWorkItem: targetWorkItem,
        currentSessionNotes: notes,
        targetCategoryId: targetCategoryId,
        targetTagIds: targetTagIds ?? const [],
        targetPeopleIds: targetPeopleIds ?? const [],
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
        categoryId: targetCategoryId,
        tagIds: targetTagIds ?? const [],
        peopleIds: targetPeopleIds ?? const [],
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
