import 'dart:convert';
import 'dart:typed_data';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/repositories/attribute_repository.dart';
import 'package:workpulse/domain/repositories/category_repository.dart';
import 'package:workpulse/domain/repositories/idle_period_repository.dart';
import 'package:workpulse/domain/repositories/person_repository.dart';
import 'package:workpulse/domain/repositories/project_repository.dart';
import 'package:workpulse/domain/repositories/session_repository.dart';
import 'package:workpulse/domain/repositories/tag_repository.dart';
import 'package:workpulse/domain/repositories/work_item_repository.dart';
import 'package:workpulse/domain/repositories/workspace_repository.dart';
import 'package:workpulse/core/platform/user_info_service.dart';
import 'package:workpulse/domain/services/pdf_report_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';

class SessionExportRecord {
  final Session session;
  final WorkItem workItem;
  final Project? project;
  final Category? category;
  final List<Tag> tags;
  final List<Person> people;
  final List<IdlePeriod> idlePeriods;
  final Duration grossDuration;
  final Duration idleDuration;
  final Duration netActiveDuration;
  final Map<String, String> attributeValues; // definitionId -> formatted string

  /// Option ids behind [attributeValues], for select-typed definitions.
  ///
  /// Ids, not labels: a code mapping keyed on a label books hours to the wrong
  /// code the moment the user renames an option, and says nothing when it does.
  /// A single-select yields one id; a multi-select yields the ids it holds.
  final Map<String, List<String>> attributeOptionIds;

  /// The session's effective classification: its own override where it has
  /// one, otherwise the task's. Resolved once, here, so every report and
  /// export downstream agrees about which hours are capitalizable.
  final FinancialClassification classification;

  /// Whether that value came from the session rather than the task.
  final bool classificationIsOverride;

  const SessionExportRecord({
    required this.session,
    required this.workItem,
    this.project,
    this.category,
    this.tags = const [],
    this.people = const [],
    this.idlePeriods = const [],
    required this.grossDuration,
    required this.idleDuration,
    required this.netActiveDuration,
    this.attributeValues = const {},
    this.attributeOptionIds = const {},
    this.classification = FinancialClassification.none,
    this.classificationIsOverride = false,
  });
}

class ExportService {
  final WorkspaceRepository _workspaceRepository;
  final SessionRepository _sessionRepository;
  final WorkItemRepository _workItemRepository;
  final ProjectRepository _projectRepository;
  final CategoryRepository _categoryRepository;
  final TagRepository _tagRepository;
  final PersonRepository _personRepository;
  final AttributeRepository _attributeRepository;
  final IdlePeriodRepository _idlePeriodRepository;
  final PdfReportService _pdfReportService;

  ExportService({
    required WorkspaceRepository workspaceRepository,
    required SessionRepository sessionRepository,
    required WorkItemRepository workItemRepository,
    required ProjectRepository projectRepository,
    required CategoryRepository categoryRepository,
    required TagRepository tagRepository,
    required PersonRepository personRepository,
    required AttributeRepository attributeRepository,
    required IdlePeriodRepository idlePeriodRepository,
    PdfReportService? pdfReportService,
  })  : _workspaceRepository = workspaceRepository,
        _sessionRepository = sessionRepository,
        _workItemRepository = workItemRepository,
        _projectRepository = projectRepository,
        _categoryRepository = categoryRepository,
        _tagRepository = tagRepository,
        _personRepository = personRepository,
        _attributeRepository = attributeRepository,
        _idlePeriodRepository = idlePeriodRepository,
        _pdfReportService = pdfReportService ?? PdfReportService();

  /// Retrieves structured export records within a date range.
  Future<List<SessionExportRecord>> getExportRecords({
    required String workspaceId,
    required DateRange range,
  }) async {
    final allSessions =
        await _sessionRepository.getByDateRange(range.start, range.end);
    // includeArchived: true - a session for an archived task must still
    // appear in Time Log / Session History / CSV / JSON export.
    final allWorkItems = await _workItemRepository.getAll(
        workspaceId: workspaceId, includeArchived: true);
    final allProjects =
        await _projectRepository.getAll(workspaceId: workspaceId);
    final allCategories =
        await _categoryRepository.getAll(workspaceId: workspaceId);
    final allTags = await _tagRepository.getAll(workspaceId: workspaceId);
    final allPeople = await _personRepository.getAll(workspaceId: workspaceId);
    final allDefinitions =
        await _attributeRepository.getDefinitions(workspaceId: workspaceId);

    final workItemMap = {for (final w in allWorkItems) w.id: w};
    final projectMap = {for (final p in allProjects) p.id: p};
    final categoryMap = {for (final c in allCategories) c.id: c};
    final tagMap = {for (final t in allTags) t.id: t};
    final personMap = {for (final p in allPeople) p.id: p};

    final optionCache = <String, Map<String, AttributeOption>>{};
    for (final def in allDefinitions) {
      if (def.type == AttributeType.singleSelect ||
          def.type == AttributeType.multiSelect) {
        final opts = await _attributeRepository.getOptions(def.id,
            includeArchived: true);
        optionCache[def.id] = {for (final o in opts) o.id: o};
      }
    }

    final records = <SessionExportRecord>[];

    for (final s in allSessions) {
      final workItem = workItemMap[s.workItemId];
      if (workItem == null) continue;

      final project = projectMap[workItem.projectId];
      // Each session's own classification. An export is a record of what was
      // tracked, so it must not quietly attribute a session to the work item's
      // category when the user left that session unclassified.
      final category = categoryMap[s.categoryId];

      // Tags
      final itemTags =
          s.tagIds.map((tid) => tagMap[tid]).whereType<Tag>().toList();

      // People
      final itemPeople =
          s.peopleIds.map((pid) => personMap[pid]).whereType<Person>().toList();

      // Idle Periods
      final idles = await _idlePeriodRepository.getIdlePeriodsForSession(s.id);
      Duration totalIdle = Duration.zero;
      for (final idl in idles) {
        if (idl.resolution == IdleResolution.markIdle) {
          totalIdle += idl.duration;
        }
      }

      final gross = s.duration;
      final net = gross > totalIdle ? gross - totalIdle : Duration.zero;

      // Custom Attributes (Task + Session values)
      final taskValues =
          await _attributeRepository.getWorkItemValues(workItem.id);
      final sessionValues = await _attributeRepository.getSessionValues(s.id);

      final attrMap = <String, String>{};
      final attrOptionIds = <String, List<String>>{};

      for (final def in allDefinitions) {
        if (def.isArchived || !def.enabled) continue;

        String? formatted;
        String? optionId;
        String? textValue;

        if (def.scope == AttributeScope.session) {
          final sVal = sessionValues
              .where((v) => v.attributeDefinitionId == def.id)
              .firstOrNull;
          if (sVal != null) {
            optionId = sVal.optionId;
            textValue = sVal.textValue;
            formatted = _formatAttributeValue(
                def,
                sVal.textValue,
                sVal.numberValue,
                sVal.booleanValue,
                sVal.dateValue,
                sVal.optionId,
                optionCache[def.id]);
          }
        } else {
          final tVal = taskValues
              .where((v) => v.attributeDefinitionId == def.id)
              .firstOrNull;
          if (tVal != null) {
            optionId = tVal.optionId;
            textValue = tVal.textValue;
            formatted = _formatAttributeValue(
                def,
                tVal.textValue,
                tVal.numberValue,
                tVal.booleanValue,
                tVal.dateValue,
                tVal.optionId,
                optionCache[def.id]);
          }
        }

        if (formatted != null && formatted.isNotEmpty) {
          attrMap[def.id] = formatted;
        }

        if (def.type == AttributeType.singleSelect &&
            optionId != null &&
            optionId.isNotEmpty) {
          attrOptionIds[def.id] = [optionId];
        } else if (def.type == AttributeType.multiSelect &&
            textValue != null &&
            textValue.isNotEmpty) {
          final ids =
              textValue.split(',').where((id) => id.trim().isNotEmpty).toList();
          if (ids.isNotEmpty) {
            attrOptionIds[def.id] = ids;
          }
        }
      }

      records.add(
        SessionExportRecord(
          session: s,
          workItem: workItem,
          project: project,
          category: category,
          tags: itemTags,
          people: itemPeople,
          idlePeriods: idles,
          grossDuration: gross,
          idleDuration: totalIdle,
          netActiveDuration: net,
          attributeValues: attrMap,
          attributeOptionIds: attrOptionIds,
          classification:
              s.classificationWithin(workItem.financialClassification),
          classificationIsOverride: s.hasClassificationOverride,
        ),
      );
    }

    records.sort((a, b) => b.session.startTime.compareTo(a.session.startTime));
    return records;
  }

  /// Generates RFC 4180 standard CSV string.
  Future<String> generateCsv({
    required String workspaceId,
    required DateRange range,
  }) async {
    final records =
        await getExportRecords(workspaceId: workspaceId, range: range);
    final definitions =
        (await _attributeRepository.getDefinitions(workspaceId: workspaceId))
            .where((d) => d.enabled && !d.isArchived)
            .toList();

    final allCodes =
        await _projectRepository.getAllTimesheetCodes(workspaceId: workspaceId);
    final codesByProject = <String, Map<String, String>>{};
    for (final c in allCodes) {
      codesByProject.putIfAbsent(c.projectId, () => {})[c.attributeOptionId] =
          c.code;
    }

    final allProjects = await _projectRepository.getAll(
        workspaceId: workspaceId, includeArchived: true);
    final optionsById = <String, AttributeOption>{};
    for (final p in allProjects) {
      final defId = p.codeAttributeDefinitionId;
      if (defId != null && defId.isNotEmpty) {
        final opts =
            await _attributeRepository.getOptions(defId, includeArchived: true);
        for (final o in opts) {
          optionsById[o.id] = o;
        }
      }
    }

    final codeResolver = TimesheetCodeResolver(
      codesByProject: codesByProject,
      optionsById: optionsById,
    );

    final buffer = StringBuffer();

    // 1. Build Header
    final headers = [
      'Date',
      'Start Time (UTC)',
      'End Time (UTC)',
      'Project',
      'Timesheet Code',
      'Timesheet Code Source',
      'Category',
      'WorkItem',
      'Financial Classification',
      'Classification Source',
      'Notes',
      'Tags',
      'People',
      'Gross Duration',
      'Idle Duration',
      'Net Duration',
      'Gross Seconds',
      'Net Seconds',
      ...definitions.map((d) => d.name),
    ];

    buffer.writeln(headers.map(_escapeCsv).join(','));

    // 2. Build Rows
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');

    for (final r in records) {
      final s = r.session;
      final dateStr = dateFormat.format(s.startTime.toLocal());
      final startStr = timeFormat.format(s.startTime);
      final endStr =
          s.endTime != null ? timeFormat.format(s.endTime!) : 'In Progress';
      final projStr = r.project?.name ?? '';

      final resolution = codeResolver.resolveFor(
        project: r.project,
        attributeOptionIds: r.attributeOptionIds,
      );
      final projCodeStr = resolution.code ?? '';
      final codeSourceStr = switch (resolution.source) {
        TimesheetCodeSource.optionMapping => 'option_mapping',
        TimesheetCodeSource.projectDefault => 'project_default',
        TimesheetCodeSource.unmappedOption => 'unmapped_option',
        TimesheetCodeSource.missingCode => 'missing_code',
        TimesheetCodeSource.unknownProject => 'unknown_project',
      };

      final catStr = r.category?.name ?? '';
      final taskStr = r.workItem.name;
      final classStr = r.classification.value;
      // Which row of the model produced that value, so a reviewer can tell a
      // deliberate one-off from the task's standing answer.
      final classSourceStr = r.classificationIsOverride ? 'SESSION' : 'TASK';
      final notesStr = s.notes ?? '';
      final tagsStr = r.tags.map((t) => t.name).join('; ');
      final peopleStr = r.people.map((p) => p.name).join('; ');
      final grossStr = formatDurationHms(r.grossDuration);
      final idleStr = formatDurationHms(r.idleDuration);
      final netStr = formatDurationHms(r.netActiveDuration);
      final grossSec = r.grossDuration.inSeconds.toString();
      final netSec = r.netActiveDuration.inSeconds.toString();

      final customFields =
          definitions.map((def) => r.attributeValues[def.id] ?? '').toList();

      final row = [
        dateStr,
        startStr,
        endStr,
        projStr,
        projCodeStr,
        codeSourceStr,
        catStr,
        taskStr,
        classStr,
        classSourceStr,
        notesStr,
        tagsStr,
        peopleStr,
        grossStr,
        idleStr,
        netStr,
        grossSec,
        netSec,
        ...customFields,
      ];

      buffer.writeln(row.map(_escapeCsv).join(','));
    }

    return buffer.toString();
  }

  /// Generates full structured JSON export.
  Future<String> generateJson({
    required String workspaceId,
    required DateRange range,
  }) async {
    final workspace = await _workspaceRepository.getById(workspaceId);
    final records =
        await getExportRecords(workspaceId: workspaceId, range: range);
    final definitions =
        (await _attributeRepository.getDefinitions(workspaceId: workspaceId))
            .where((d) => d.enabled && !d.isArchived)
            .toList();

    Duration totalGross = Duration.zero;
    Duration totalIdle = Duration.zero;
    Duration totalNet = Duration.zero;

    for (final r in records) {
      totalGross += r.grossDuration;
      totalIdle += r.idleDuration;
      totalNet += r.netActiveDuration;
    }

    final payload = {
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'version': '1.0.0',
      'workspace': {
        'id': workspace?.id ?? workspaceId,
        'name': workspace?.name ?? 'Default Workspace',
      },
      'range': {
        'startDate': range.start.toUtc().toIso8601String(),
        'endDate': range.end.toUtc().toIso8601String(),
      },
      'summary': {
        'sessionCount': records.length,
        'totalGrossDurationSeconds': totalGross.inSeconds,
        'totalIdleDurationSeconds': totalIdle.inSeconds,
        'totalNetDurationSeconds': totalNet.inSeconds,
        'totalGrossDurationFormatted':
            TimerService.formatDuration(totalGross, includeSeconds: true),
        'totalNetDurationFormatted':
            TimerService.formatDuration(totalNet, includeSeconds: true),
      },
      'attributeDefinitions': definitions
          .map<Map<String, dynamic>>((d) => {
                'id': d.id,
                'key': d.key,
                'name': d.name,
                'type': d.type.name,
                'scope': d.scope.name,
              })
          .toList(),
      'sessions': records.map((r) {
        final s = r.session;
        return {
          'id': s.id,
          'startTime': s.startTime.toUtc().toIso8601String(),
          'endTime': s.endTime?.toUtc().toIso8601String(),
          'notes': s.notes,
          'grossDurationSeconds': r.grossDuration.inSeconds,
          'idleDurationSeconds': r.idleDuration.inSeconds,
          'netDurationSeconds': r.netActiveDuration.inSeconds,
          'financialClassification': r.classification.value,
          'financialClassificationSource':
              r.classificationIsOverride ? 'SESSION' : 'TASK',
          'workItem': {
            'id': r.workItem.id,
            'name': r.workItem.name,
            'financialClassification': r.workItem.financialClassification.value,
            'legacyNotes': r.workItem.notes,
          },
          'project': r.project != null
              ? {
                  'id': r.project!.id,
                  'name': r.project!.name,
                  'colorHex': r.project!.colorHex,
                  'timesheetCode': r.project!.timesheetCode,
                }
              : null,
          'category': r.category != null
              ? {
                  'id': r.category!.id,
                  'name': r.category!.name,
                  'iconName': r.category!.iconName,
                }
              : null,
          'tags': r.tags
              .map((t) => {'id': t.id, 'name': t.name, 'colorHex': t.colorHex})
              .toList(),
          'people': r.people.map((p) => {'id': p.id, 'name': p.name}).toList(),
          'idlePeriods': r.idlePeriods
              .map((i) => {
                    'id': i.id,
                    'startTime': i.startTime.toUtc().toIso8601String(),
                    'endTime': i.endTime.toUtc().toIso8601String(),
                    'durationSeconds': i.duration.inSeconds,
                    'resolution': i.resolution.name,
                  })
              .toList(),
          'attributes': r.attributeValues,
        };
      }).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Generates colorful, modern executive PDF report bytes.
  Future<Uint8List> generatePdf({
    required String workspaceId,
    required DateRange range,
    String? userName,
  }) async {
    final workspace = await _workspaceRepository.getById(workspaceId);
    final records =
        await getExportRecords(workspaceId: workspaceId, range: range);
    final definitions =
        (await _attributeRepository.getDefinitions(workspaceId: workspaceId))
            .where((d) => d.enabled && !d.isArchived)
            .toList();

    final effectiveUserName =
        userName ?? await UserInfoService.getCurrentUserFullName();

    return _pdfReportService.generateReportPdf(
      workspaceName: workspace?.name ?? 'Default Workspace',
      range: range,
      records: records,
      attributeDefinitions: definitions,
      userName: effectiveUserName,
    );
  }

  String _formatAttributeValue(
    AttributeDefinition def,
    String? text,
    double? number,
    bool? boolean,
    DateTime? date,
    String? optionId,
    Map<String, AttributeOption>? options,
  ) {
    switch (def.type) {
      case AttributeType.text:
        return text ?? '';
      case AttributeType.number:
        return number != null
            ? (number % 1 == 0 ? number.toInt().toString() : number.toString())
            : '';
      case AttributeType.boolean:
        return boolean != null ? (boolean ? 'Yes' : 'No') : '';
      case AttributeType.date:
        return date != null
            ? DateFormat('yyyy-MM-dd').format(date.toLocal())
            : '';
      case AttributeType.singleSelect:
        if (optionId != null && options != null) {
          return options[optionId]?.label ?? optionId;
        }
        return optionId ?? '';
      case AttributeType.multiSelect:
        if (text != null && text.isNotEmpty && options != null) {
          final optIds = text.split(',');
          return optIds.map((id) => options[id]?.label ?? id).join('; ');
        }
        return text ?? '';
    }
  }

  static String formatDurationHms(Duration duration) {
    if (duration.isNegative) return '00:00:00';
    final totalSeconds = duration.inSeconds;
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }
}
