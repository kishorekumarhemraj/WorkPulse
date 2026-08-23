import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';

final taskTotalDurationProvider = FutureProvider.family<Duration, String>((ref, workItemId) async {
  final timerService = ref.watch(timerServiceProvider);
  final timerState = ref.watch(timerProvider).value;

  final activeSession = (timerState != null &&
          timerState.isRunning &&
          timerState.activeWorkItem?.id == workItemId)
      ? timerState.activeSession
      : null;

  return timerService.getWorkItemTotalDuration(
    workItemId,
    activeSession: activeSession,
  );
});
