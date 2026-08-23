import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/platform/idle_detector_service.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/idle_service.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';

final idleDetectorServiceProvider = Provider<IdleDetectorService>((ref) {
  final service = DesktopIdleDetectorService();
  ref.onDispose(service.dispose);
  return service;
});

final idleServiceProvider = Provider<IdleService>((ref) {
  return IdleService(
    sessionRepository: ref.watch(sessionRepositoryProvider),
    idlePeriodRepository: ref.watch(idlePeriodRepositoryProvider),
    timerService: ref.watch(timerServiceProvider),
  );
});

class IdleState extends Equatable {
  final bool isPromptVisible;
  final IdleDetectionEvent? currentEvent;
  final WorkItem? activeWorkItem;
  final Session? activeSession;

  const IdleState({
    this.isPromptVisible = false,
    this.currentEvent,
    this.activeWorkItem,
    this.activeSession,
  });

  IdleState copyWith({
    bool? isPromptVisible,
    IdleDetectionEvent? currentEvent,
    WorkItem? activeWorkItem,
    Session? activeSession,
  }) {
    return IdleState(
      isPromptVisible: isPromptVisible ?? this.isPromptVisible,
      currentEvent: currentEvent ?? this.currentEvent,
      activeWorkItem: activeWorkItem ?? this.activeWorkItem,
      activeSession: activeSession ?? this.activeSession,
    );
  }

  @override
  List<Object?> get props => [isPromptVisible, currentEvent, activeWorkItem, activeSession];
}

final idleNotifierProvider = NotifierProvider<IdleNotifier, IdleState>(
  IdleNotifier.new,
);

class IdleNotifier extends Notifier<IdleState> {
  StreamSubscription<IdleDetectionEvent>? _subscription;

  IdleService get _idleService => ref.read(idleServiceProvider);
  IdleDetectorService get _detectorService => ref.read(idleDetectorServiceProvider);

  @override
  IdleState build() {
    _subscription?.cancel();
    _subscription = _detectorService.onIdleDetected.listen(_handleIdleDetected);

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return const IdleState();
  }

  void _handleIdleDetected(IdleDetectionEvent event) {
    final timerState = ref.read(timerProvider).value;
    if (timerState == null || !timerState.isRunning || timerState.activeSession == null || timerState.activeWorkItem == null) {
      return;
    }

    state = state.copyWith(
      isPromptVisible: true,
      currentEvent: event,
      activeWorkItem: timerState.activeWorkItem,
      activeSession: timerState.activeSession,
    );
  }

  /// Manually trigger idle prompt (e.g. for testing / shortcuts)
  void triggerPrompt({
    required Duration idleDuration,
    DateTime? startTime,
  }) {
    final timerState = ref.read(timerProvider).value;
    if (timerState == null || !timerState.isRunning || timerState.activeSession == null || timerState.activeWorkItem == null) {
      return;
    }

    final now = DateTime.now().toUtc();
    final start = startTime ?? now.subtract(idleDuration);

    state = state.copyWith(
      isPromptVisible: true,
      currentEvent: IdleDetectionEvent(
        idleDuration: idleDuration,
        idleStartTime: start,
        idleEndTime: now,
      ),
      activeWorkItem: timerState.activeWorkItem,
      activeSession: timerState.activeSession,
    );
  }

  /// Option 1: Keep tracking current task
  Future<void> keepTracking() async {
    final current = state;
    if (current.currentEvent == null || current.activeSession == null) {
      dismiss();
      return;
    }

    await _idleService.resolveKeepTracking(
      sessionId: current.activeSession!.id,
      idleStartTime: current.currentEvent!.idleStartTime,
      idleEndTime: current.currentEvent!.idleEndTime,
    );

    dismiss();
  }

  /// Option 2: Discard idle time & resume active task
  Future<void> markIdle() async {
    final current = state;
    if (current.currentEvent == null || current.activeSession == null || current.activeWorkItem == null) {
      dismiss();
      return;
    }

    final result = await _idleService.resolveMarkIdle(
      sessionId: current.activeSession!.id,
      workItemId: current.activeWorkItem!.id,
      idleStartTime: current.currentEvent!.idleStartTime,
      idleEndTime: current.currentEvent!.idleEndTime,
    );

    // Refresh timer provider with the newly started session
    if (result.newSession != null) {
      ref.read(timerProvider.notifier).recoverActiveSession();
    }

    dismiss();
  }

  /// Option 3: Stop tracking at the moment user went idle
  Future<void> stopSession() async {
    final current = state;
    if (current.currentEvent == null || current.activeSession == null) {
      dismiss();
      return;
    }

    await _idleService.resolveStopSession(
      sessionId: current.activeSession!.id,
      idleStartTime: current.currentEvent!.idleStartTime,
      idleEndTime: current.currentEvent!.idleEndTime,
    );

    // Update timer state to idle
    ref.read(timerProvider.notifier).recoverActiveSession();

    dismiss();
  }

  void dismiss() {
    state = const IdleState(isPromptVisible: false);
  }
}
