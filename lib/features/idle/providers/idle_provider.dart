import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/platform/idle_detector_service.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/activity_heartbeat_service.dart';
import 'package:workpulse/domain/services/idle_gap_service.dart';
import 'package:workpulse/domain/services/idle_service.dart';
import 'package:workpulse/features/settings/providers/app_settings_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';

final idleDetectorServiceProvider = Provider<IdleDetectorService>((ref) {
  final service = DesktopIdleDetectorService();

  // The threshold is a user setting, so the live detector follows it rather
  // than being rebuilt (which would drop the subscription IdleNotifier holds
  // and restart the poll from zero).
  final initial = ref.read(appSettingsProvider).value?.idleThreshold;
  if (initial != null) service.setIdleThreshold(initial);

  ref.listen<AsyncValue<AppSettings>>(appSettingsProvider, (_, next) {
    final threshold = next.value?.idleThreshold;
    if (threshold != null) service.setIdleThreshold(threshold);
  });

  ref.onDispose(service.dispose);
  return service;
});

final activityHeartbeatServiceProvider =
    Provider<ActivityHeartbeatService>((ref) {
  final service = ActivityHeartbeatService(
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final idleGapServiceProvider = Provider<IdleGapService>((ref) {
  return IdleGapService(
    sessionRepository: ref.watch(sessionRepositoryProvider),
    heartbeatService: ref.watch(activityHeartbeatServiceProvider),
  );
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
  List<Object?> get props =>
      [isPromptVisible, currentEvent, activeWorkItem, activeSession];
}

final idleNotifierProvider = NotifierProvider<IdleNotifier, IdleState>(
  IdleNotifier.new,
);

class IdleNotifier extends Notifier<IdleState> {
  StreamSubscription<IdleDetectionEvent>? _subscription;

  /// Startup recovery is a once-per-launch job. The shell that kicks it off is
  /// torn down and rebuilt every time the Quick Capture window takes over, and
  /// a second pass would only ever measure against a heartbeat this same run
  /// just wrote.
  bool _hasCheckedForUnaccountedGap = false;

  IdleService get _idleService => ref.read(idleServiceProvider);
  IdleDetectorService get _detectorService =>
      ref.read(idleDetectorServiceProvider);
  IdleGapService get _gapService => ref.read(idleGapServiceProvider);
  ActivityHeartbeatService get _heartbeatService =>
      ref.read(activityHeartbeatServiceProvider);

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
    if (timerState == null ||
        !timerState.isRunning ||
        timerState.activeSession == null ||
        timerState.activeWorkItem == null) {
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
    if (timerState == null ||
        !timerState.isRunning ||
        timerState.activeSession == null ||
        timerState.activeWorkItem == null) {
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

  /// Startup recovery for time the app was not around to watch.
  ///
  /// The live detector's polling timer dies with the process, so quitting
  /// WorkPulse — or shutting the Mac down — with a timer running leaves a
  /// session whose `end_time` is still null and whose elapsed time keeps
  /// growing off wall-clock alone. On the next launch that reads back as hours
  /// of solid work that nobody did. Reconstruct that gap from the persisted
  /// heartbeat and offer the same three resolutions as live inactivity.
  Future<void> checkForUnaccountedGap() async {
    if (_hasCheckedForUnaccountedGap || state.isPromptVisible) return;
    _hasCheckedForUnaccountedGap = true;

    final timerState = await ref.read(timerProvider.future);
    if (!timerState.isRunning ||
        timerState.activeSession == null ||
        timerState.activeWorkItem == null) {
      // Nothing is being tracked, so nothing can be over-counted. Re-baseline
      // so the next launch measures from here.
      await _heartbeatService.beat();
      return;
    }

    final gap = await _gapService.detectUnaccountedGap(
      threshold: _detectorService.idleThreshold,
    );

    if (gap == null || gap.session.id != timerState.activeSession!.id) {
      await _heartbeatService.beat();
      return;
    }

    state = state.copyWith(
      isPromptVisible: true,
      currentEvent: IdleDetectionEvent(
        idleDuration: gap.duration,
        idleStartTime: gap.startTime,
        idleEndTime: gap.endTime,
        trigger: IdleTrigger.appNotRunning,
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

    // The gap is now resolved; re-baseline so the next launch does not ask
    // about the same stretch of time again.
    await _heartbeatService.beat();

    dismiss();
  }

  /// Option 2: Discard idle time & resume active task
  Future<void> markIdle() async {
    final current = state;
    if (current.currentEvent == null ||
        current.activeSession == null ||
        current.activeWorkItem == null) {
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
      await ref.read(timerProvider.notifier).recoverActiveSession();
    }

    await _heartbeatService.beat();

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
    await ref.read(timerProvider.notifier).recoverActiveSession();

    await _heartbeatService.beat();

    dismiss();
  }

  void dismiss() {
    state = const IdleState(isPromptVisible: false);
  }
}
