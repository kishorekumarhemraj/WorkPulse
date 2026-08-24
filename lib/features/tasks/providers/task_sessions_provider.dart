import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/session_model.dart';

import 'package:workpulse/features/timer/providers/timer_provider.dart';

/// All sessions logged against a single work item, newest first.
/// Backs both the Sessions section in TaskFormDialog and the derived
/// task-notes rollup (both need the same underlying list).
final sessionsForWorkItemProvider =
    FutureProvider.family<List<Session>, String>((ref, workItemId) async {
  // Invalidate when active session starts/stops/switches
  ref.watch(timerProvider.select((s) => s.value?.activeSession?.id));
  return ref.watch(sessionRepositoryProvider).getByWorkItemId(workItemId);
});
