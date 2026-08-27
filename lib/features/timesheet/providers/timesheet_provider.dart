import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/domain/services/timesheet_service.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

final timesheetServiceProvider = Provider<TimesheetService>((ref) {
  return const TimesheetService();
});

/// Whether the Time Sheet reports net (idle excluded) or gross hours.
final timesheetHoursBasisProvider =
    NotifierProvider<TimesheetHoursBasisNotifier, TimesheetHoursBasis>(
  TimesheetHoursBasisNotifier.new,
);

class TimesheetHoursBasisNotifier extends Notifier<TimesheetHoursBasis> {
  @override
  TimesheetHoursBasis build() => TimesheetHoursBasis.net;

  void setBasis(TimesheetHoursBasis basis) => state = basis;
}

/// The CAPEX/OPEX tables for the range currently selected on the reporting
/// screens.
///
/// Built on top of [sessionHistoryProvider] rather than issuing its own
/// queries: the Time Log has already resolved every session in range to its
/// project, category and attribute values, and re-reading all of it to
/// compute sums would double the database work for identical data.
///
/// Both hour bases are computed here, so the Net/Gross toggle repaints
/// without touching the database.
final timesheetDataProvider = FutureProvider<TimesheetData>((ref) async {
  final records = await ref.watch(sessionHistoryProvider.future);
  final definitions = await ref.watch(attributeDefinitionsProvider.future);
  final projects = await ref.watch(projectsProvider.future);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  final projectRepo = ref.watch(projectRepositoryProvider);
  final attributeRepo = ref.watch(attributeRepositoryProvider);
  final range = ref.watch(reportsDateRangeProvider);
  final service = ref.watch(timesheetServiceProvider);

  final allCodes =
      await projectRepo.getAllTimesheetCodes(workspaceId: workspace.id);
  final codesByProject = <String, Map<String, String>>{};
  for (final c in allCodes) {
    codesByProject.putIfAbsent(c.projectId, () => {})[c.attributeOptionId] =
        c.code;
  }

  final optionsById = <String, AttributeOption>{};
  for (final p in projects) {
    final defId = p.codeAttributeDefinitionId;
    if (defId != null && defId.isNotEmpty) {
      final opts =
          await attributeRepo.getOptions(defId, includeArchived: true);
      for (final o in opts) {
        optionsById[o.id] = o;
      }
    }
  }

  final resolver = TimesheetCodeResolver(
    codesByProject: codesByProject,
    optionsById: optionsById,
  );

  return service.build(
    range: range,
    records: records,
    definitions: definitions,
    codes: resolver,
  );
});

