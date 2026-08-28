import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

/// All sessions logged against a single work item, newest first.
/// Backs both the Sessions section in TaskFormDialog and the derived
/// task-notes rollup (both need the same underlying list).
final sessionsForWorkItemProvider =
    FutureProvider.family<List<Session>, String>((ref, workItemId) async {
  // Invalidate when active session starts/stops/switches
  ref.watch(timerProvider.select((s) => s.value?.activeSession?.id));
  return ref.watch(sessionRepositoryProvider).getByWorkItemId(workItemId);
});

/// Every session on one work item, fully hydrated — the same records the
/// Time Log renders, scoped to one task.
///
/// [sessionsForWorkItemProvider] stays for TaskFormDialog, which only needs
/// ids and must not pay for attribute hydration on every keystroke.
final workItemSessionRecordsProvider =
    FutureProvider.family<List<SessionExportRecord>, String>((ref, id) async {
  ref.watch(timerProvider.select((s) => s.value?.activeSession?.id));
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  return ref
      .watch(exportServiceProvider)
      .getExportRecordsForWorkItem(workspaceId: workspace.id, workItemId: id);
});
