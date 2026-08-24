import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/pdf_report_service.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/tasks/providers/task_sessions_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

const _uuid = Uuid();

final pdfReportServiceProvider = Provider<PdfReportService>((ref) {
  return PdfReportService();
});

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
    pdfReportService: ref.watch(pdfReportServiceProvider),
  );
});

final reportsTimeRangeProvider =
    NotifierProvider<ReportsTimeRangeNotifier, DashboardTimeRange>(
  ReportsTimeRangeNotifier.new,
);

class ReportsTimeRangeNotifier extends Notifier<DashboardTimeRange> {
  @override
  DashboardTimeRange build() => DashboardTimeRange.thisWeek;

  void setRange(DashboardTimeRange range) => state = range;
}

final reportsDateProvider =
    NotifierProvider<ReportsDateNotifier, DateTime>(
  ReportsDateNotifier.new,
);

class ReportsDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }

  void previousDay() {
    state = DateTime(state.year, state.month, state.day - 1);
  }

  void nextDay() {
    state = DateTime(state.year, state.month, state.day + 1);
  }

  void goToToday() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, now.day);
  }
}

final sessionHistoryProvider =
    FutureProvider<List<SessionExportRecord>>((ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  final timeRange = ref.watch(reportsTimeRangeProvider);
  final selectedDate = ref.watch(reportsDateProvider);
  final exportService = ref.watch(exportServiceProvider);

  // Invalidate when timer state changes to reflect freshly stopped sessions
  ref.watch(timerProvider.select((s) => s.value?.activeSession?.id));

  DateRange calculatedRange;
  switch (timeRange) {
    case DashboardTimeRange.today:
      final now = DateTime.now();
      final localStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final localEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      calculatedRange =
          DateRange(start: localStart.toUtc(), end: localEnd.toUtc());
      break;
    case DashboardTimeRange.thisWeek:
      calculatedRange = DashboardTimeRange.thisWeek.toDateRange();
      break;
    case DashboardTimeRange.thisMonth:
      calculatedRange = DashboardTimeRange.thisMonth.toDateRange();
      break;
    case DashboardTimeRange.custom:
      final localStart = DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
      final localEnd = DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59, 999);
      calculatedRange = DateRange(
        start: localStart.toUtc(),
        end: localEnd.toUtc(),
      );
      break;
  }

  return exportService.getExportRecords(
    workspaceId: workspace.id,
    range: calculatedRange,
  );
});

final sessionEditorControllerProvider =
    Provider<SessionEditorController>((ref) {
  return SessionEditorController(ref);
});

class SessionEditorController {
  final Ref _ref;

  SessionEditorController(this._ref);

  Future<void> updateSession({
    required String sessionId,
    DateTime? startTime,
    DateTime? endTime,
    String? categoryId,
    bool clearCategory = false,
    String? notes,
    bool clearNotes = false,
    List<String>? tagIds,
    List<String>? peopleIds,
    Map<String, dynamic> attributeValues = const {},
  }) async {
    final sessionRepo = _ref.read(sessionRepositoryProvider);
    final session = await sessionRepo.getById(sessionId);
    if (session == null) return;

    final updated = session.copyWith(
      startTime: startTime ?? session.startTime,
      endTime: endTime ?? session.endTime,
      categoryId: clearCategory ? null : (categoryId ?? session.categoryId),
      tagIds: tagIds ?? session.tagIds,
      peopleIds: peopleIds ?? session.peopleIds,
      notes: notes,
      clearNotes: clearNotes,
    );

    await sessionRepo.update(updated);

    // Additive merge: people newly tagged on this session that aren't
    // already on the parent task get unioned into WorkItem.peopleIds.
    // One-directional and permanent by design - deleting a session does
    // NOT remove its people from the task. Not wrapped in the same DB
    // transaction as the session write above; if the app crashes between
    // the two writes, the merge is simply re-run (idempotent) on the
    // next session edit for that person.
    if (peopleIds != null && peopleIds.isNotEmpty) {
      final workItemRepo = _ref.read(workItemRepositoryProvider);
      final workItem = await workItemRepo.getById(session.workItemId);
      if (workItem != null) {
        final missing =
            peopleIds.where((id) => !workItem.peopleIds.contains(id)).toList();
        if (missing.isNotEmpty) {
          await workItemRepo.update(
            workItem.copyWith(peopleIds: [...workItem.peopleIds, ...missing]),
          );
          _ref.invalidate(workItemsProvider);
        }
      }
    }

    // Save session-scoped attributes if provided
    if (attributeValues.isNotEmpty) {
      final attrRepo = _ref.read(attributeRepositoryProvider);
      final definitions = _ref.read(attributeDefinitionsProvider).value ?? [];
      final sessionDefs = definitions
          .where((d) =>
              d.scope == AttributeScope.session && d.enabled && !d.isArchived)
          .toList();
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
            numVal = entry.value is num
                ? (entry.value as num).toDouble()
                : double.tryParse(entry.value.toString());
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
            dateVal = entry.value is DateTime
                ? entry.value as DateTime
                : DateTime.tryParse(entry.value.toString());
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
    _ref.invalidate(sessionsForWorkItemProvider(session.workItemId));
  }

  Future<void> deleteSession(String sessionId) async {
    final sessionRepo = _ref.read(sessionRepositoryProvider);
    final session = await sessionRepo.getById(sessionId);
    await sessionRepo.delete(sessionId);
    _ref.invalidate(sessionHistoryProvider);
    if (session != null) {
      _ref.invalidate(sessionsForWorkItemProvider(session.workItemId));
    }
  }
}
