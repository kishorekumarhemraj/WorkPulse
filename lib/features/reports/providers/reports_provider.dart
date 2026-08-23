import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

const _uuid = Uuid();

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    workspaceRepository: ref.watch(workspaceRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
    workItemRepository: ref.watch(workItemRepositoryProvider),
    projectRepository: ref.watch(projectRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
    tagRepository: ref.watch(tagRepositoryProvider),
    personRepository: ref.watch(personRepositoryProvider),
    attributeRepository: ref.watch(attributeRepositoryProvider),
    idlePeriodRepository: ref.watch(idlePeriodRepositoryProvider),
  );
});

final reportsTimeRangeProvider = NotifierProvider<ReportsTimeRangeNotifier, DashboardTimeRange>(
  ReportsTimeRangeNotifier.new,
);

class ReportsTimeRangeNotifier extends Notifier<DashboardTimeRange> {
  @override
  DashboardTimeRange build() => DashboardTimeRange.thisWeek;

  void setRange(DashboardTimeRange range) => state = range;
}

final reportsCustomRangeProvider = NotifierProvider<ReportsCustomRangeNotifier, DateTimeRange?>(
  ReportsCustomRangeNotifier.new,
);

class ReportsCustomRangeNotifier extends Notifier<DateTimeRange?> {
  @override
  DateTimeRange? build() => null;

  void setCustomRange(DateTimeRange? range) => state = range;
}

final sessionHistoryProvider = FutureProvider<List<SessionExportRecord>>((ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  final timeRange = ref.watch(reportsTimeRangeProvider);
  final customRange = ref.watch(reportsCustomRangeProvider);
  final exportService = ref.watch(exportServiceProvider);

  // Invalidate when timer state changes to reflect freshly stopped sessions
  ref.watch(timerProvider.select((s) => s.value?.activeSession?.id));

  final calculatedRange = timeRange.toDateTimeRange(customRange: customRange);

  return exportService.getExportRecords(
    workspaceId: workspace.id,
    range: calculatedRange,
  );
});

final sessionEditorControllerProvider = Provider<SessionEditorController>((ref) {
  return SessionEditorController(ref);
});

class SessionEditorController {
  final Ref _ref;

  SessionEditorController(this._ref);

  Future<void> updateSession({
    required String sessionId,
    DateTime? startTime,
    DateTime? endTime,
    String? notes,
    Map<String, dynamic> attributeValues = const {},
  }) async {
    final sessionRepo = _ref.read(sessionRepositoryProvider);
    final session = await sessionRepo.getById(sessionId);
    if (session == null) return;

    final updated = session.copyWith(
      startTime: startTime ?? session.startTime,
      endTime: endTime ?? session.endTime,
    );

    await sessionRepo.update(updated);

    if (notes != null) {
      final workItemRepo = _ref.read(workItemRepositoryProvider);
      final workItem = await workItemRepo.getById(session.workItemId);
      if (workItem != null) {
        await workItemRepo.update(workItem.copyWith(notes: notes));
      }
    }

    // Save session-scoped attributes if provided
    if (attributeValues.isNotEmpty) {
      final attrRepo = _ref.read(attributeRepositoryProvider);
      final definitions = _ref.read(attributeDefinitionsProvider).value ?? [];
      final sessionDefs = definitions.where((d) => d.scope == AttributeScope.session && d.enabled && !d.isArchived).toList();
      final now = DateTime.now().toUtc();

      for (final entry in attributeValues.entries) {
        final def = sessionDefs.where((d) => d.id == entry.key).firstOrNull;
        if (def == null || entry.value == null) continue;

        String? textVal;
        double? numVal;
        bool? boolVal;
        DateTime? dateVal;
        String? optId;

        switch (def.type) {
          case AttributeType.text:
            textVal = entry.value.toString();
            break;
          case AttributeType.number:
            numVal = entry.value is num ? (entry.value as num).toDouble() : double.tryParse(entry.value.toString());
            break;
          case AttributeType.boolean:
            boolVal = entry.value == true;
            break;
          case AttributeType.singleSelect:
            optId = entry.value.toString();
            break;
          case AttributeType.multiSelect:
            textVal = (entry.value as List).join(',');
            break;
          case AttributeType.date:
            dateVal = entry.value is DateTime ? entry.value as DateTime : DateTime.tryParse(entry.value.toString());
            break;
        }

        await attrRepo.setSessionValue(
          SessionAttributeValue(
            id: _uuid.v4(),
            sessionId: sessionId,
            attributeDefinitionId: def.id,
            optionId: optId,
            textValue: textVal,
            numberValue: numVal,
            booleanValue: boolVal,
            dateValue: dateVal,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    _ref.invalidate(sessionHistoryProvider);
  }

  Future<void> deleteSession(String sessionId) async {
    final sessionRepo = _ref.read(sessionRepositoryProvider);
    await sessionRepo.delete(sessionId);
    _ref.invalidate(sessionHistoryProvider);
  }
}
