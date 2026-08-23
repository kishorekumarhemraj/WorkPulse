import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';

final taskTotalDurationProvider =
    FutureProvider.family<Duration, String>((ref, workItemId) async {
  final timerService = ref.watch(timerServiceProvider);
  // Invalidate only when active session starts/stops/switches
  ref.watch(timerProvider.select((s) => s.value?.activeSession?.id));

  return timerService.getWorkItemTotalDuration(workItemId);
});
