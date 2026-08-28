import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/domain/services/timesheet_service.dart';

void main() {
  final now = DateTime.utc(2026, 8, 24, 9);

  Category category(String id, String name) => Category(
        id: id,
        workspaceId: 'ws-1',
        name: name,
        createdAt: now,
        updatedAt: now,
      );

  Project project(String id, String name, {String? code}) => Project(
        id: id,
        workspaceId: 'ws-1',
        name: name,
        colorHex: '#0A84FF',
        timesheetCode: code,
        createdAt: now,
        updatedAt: now,
      );

  AttributeDefinition definition(
    String id,
    String name, {
    int displayOrder = 0,
    bool reportable = true,
    bool enabled = true,
  }) =>
      AttributeDefinition(
        id: id,
        workspaceId: 'ws-1',
        key: id,
        name: name,
        type: AttributeType.singleSelect,
        reportable: reportable,
        enabled: enabled,
        displayOrder: displayOrder,
        createdAt: now,
        updatedAt: now,
      );

  /// Builds a record the way ExportService does: the classification is
  /// resolved once, from the session's override where it has one and from the
  /// task otherwise, so the service under test never sees which spoke.
  SessionExportRecord record({
    required String id,
    required Duration gross,
    Project? proj,
    Category? cat,
    String taskId = 'wi-1',
    String taskName = 'Build the thing',
    FinancialClassification task = FinancialClassification.capex,
    FinancialClassification? override,
    Duration idle = Duration.zero,
    Map<String, String> attributes = const {},
    Map<String, List<String>> optionIds = const {},
  }) {
    final item = WorkItem(
      id: taskId,
      workspaceId: 'ws-1',
      name: taskName,
      projectId: proj?.id ?? 'proj-unknown',
      categoryId: cat?.id ?? 'cat-none',
      financialClassification: task,
      createdAt: now,
      updatedAt: now,
    );
    final session = Session(
      id: id,
      workItemId: item.id,
      categoryId: cat?.id,
      financialClassification: override,
      startTime: now,
      endTime: now.add(gross),
      createdAt: now,
    );
    return SessionExportRecord(
      session: session,
      workItem: item,
      project: proj,
      category: cat,
      grossDuration: gross,
      idleDuration: idle,
      netActiveDuration: gross - idle,
      attributeValues: attributes,
      attributeOptionIds: optionIds,
      classification:
          session.classificationWithin(item.financialClassification),
      classificationIsOverride: session.hasClassificationOverride,
    );
  }

  final coding = category('cat-coding', 'Coding');
  final meetings = category('cat-meetings', 'Meetings');
  final apollo = project('proj-apollo', 'Apollo', code: 'PRJ-1042');
  final zephyr = project('proj-zephyr', 'Zephyr');
  final costCentre = definition('def-cc', 'Cost Centre');

  final range = DateRange(start: now, end: now.add(const Duration(days: 1)));

  const service = TimesheetService();

  group('TimesheetService', () {
    test('splits hours by the classification each session resolved to', () {
      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: coding,
            gross: const Duration(hours: 3),
            task: FinancialClassification.capex,
          ),
          record(
            id: 's2',
            proj: apollo,
            cat: meetings,
            gross: const Duration(hours: 1),
            taskId: 'wi-2',
            task: FinancialClassification.opex,
          ),
        ],
        definitions: const [],
      );

      expect(data.sessionCount, 2);
      expect(data.total.net.capex, const Duration(hours: 3));
      expect(data.total.net.opex, const Duration(hours: 1));
      expect(data.total.net.none, Duration.zero);
      expect(data.total.net.capexShare, 75);
      expect(data.projectRows, hasLength(1));
    });

    test('a session override outranks the task it belongs to', () {
      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: coding,
            gross: const Duration(hours: 2),
            task: FinancialClassification.capex,
          ),
          // Same task, but this one hour was spent on something operational.
          record(
            id: 's2',
            proj: apollo,
            cat: meetings,
            gross: const Duration(hours: 1),
            task: FinancialClassification.capex,
            override: FinancialClassification.opex,
          ),
        ],
        definitions: const [],
      );

      expect(data.total.net.capex, const Duration(hours: 2));
      expect(data.total.net.opex, const Duration(hours: 1));
      // Both sessions belong to one task, so the task row carries the split.
      expect(data.taskRows, hasLength(1));
      expect(data.taskRows.single.net.capex, const Duration(hours: 2));
      expect(data.taskRows.single.net.opex, const Duration(hours: 1));
    });

    test('reports net and gross separately so the toggle needs no re-query',
        () {
      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: coding,
            gross: const Duration(hours: 2),
            idle: const Duration(minutes: 30),
          ),
        ],
        definitions: const [],
      );

      final row = data.projectRows.single;
      expect(
          row.split(TimesheetHoursBasis.gross).capex, const Duration(hours: 2));
      expect(row.split(TimesheetHoursBasis.net).capex,
          const Duration(minutes: 90));
    });

    test('carries unclassified time rather than dropping or guessing it', () {
      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: coding,
            gross: const Duration(hours: 2),
            task: FinancialClassification.none,
          ),
          record(
            id: 's2',
            proj: apollo,
            cat: coding,
            gross: const Duration(hours: 2),
            taskId: 'wi-2',
            task: FinancialClassification.capex,
          ),
        ],
        definitions: const [],
      );

      expect(data.total.net.none, const Duration(hours: 2));
      expect(data.total.net.total, const Duration(hours: 4));
      // The ratio is of classified time, so hours nobody has decided about
      // cannot quietly dilute the CapEx figure the user reports.
      expect(data.total.net.capexShare, 100);
      expect(data.total.net.hasNone, isTrue);
    });

    test('breaks each classification down by category', () {
      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: coding,
            gross: const Duration(hours: 5),
            task: FinancialClassification.capex,
          ),
          record(
            id: 's2',
            proj: apollo,
            cat: meetings,
            gross: const Duration(hours: 2),
            task: FinancialClassification.capex,
          ),
          record(
            id: 's3',
            proj: apollo,
            cat: meetings,
            gross: const Duration(hours: 1),
            taskId: 'wi-2',
            task: FinancialClassification.opex,
          ),
        ],
        definitions: const [],
      );

      // Coding versus meetings across classifications in one unified table
      expect(data.categoryRows.map((r) => r.label), ['Coding', 'Meetings']);

      final codingRow =
          data.categoryRows.firstWhere((r) => r.label == 'Coding');
      expect(codingRow.net.capex, const Duration(hours: 5));
      expect(codingRow.net.opex, Duration.zero);
      expect(codingRow.net.total, const Duration(hours: 5));

      final meetingsRow =
          data.categoryRows.firstWhere((r) => r.label == 'Meetings');
      expect(meetingsRow.net.capex, const Duration(hours: 2));
      expect(meetingsRow.net.opex, const Duration(hours: 1));
      expect(meetingsRow.net.total, const Duration(hours: 3));
    });

    test('reports time by task, carrying the project code', () {
      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: coding,
            gross: const Duration(hours: 1),
            taskId: 'wi-1',
            taskName: 'Build the thing',
          ),
          record(
            id: 's2',
            proj: apollo,
            cat: coding,
            gross: const Duration(hours: 4),
            taskId: 'wi-2',
            taskName: 'Fix the other thing',
          ),
        ],
        definitions: const [],
      );

      expect(
        data.taskRows.map((r) => r.label),
        ['Fix the other thing', 'Build the thing'],
      );
      expect(data.taskRows.first.code, 'PRJ-1042');
    });

    test('builds one table per reportable attribute, longest row first', () {
      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: coding,
            gross: const Duration(hours: 1),
            attributes: {costCentre.id: 'CC-100'},
          ),
          record(
            id: 's2',
            proj: zephyr,
            cat: meetings,
            gross: const Duration(hours: 4),
            taskId: 'wi-2',
            task: FinancialClassification.opex,
            attributes: {costCentre.id: 'CC-200'},
          ),
        ],
        definitions: [costCentre],
      );

      expect(data.attributeSections, hasLength(1));
      final rows = data.attributeSections.single.rows;
      expect(rows.map((r) => r.label), ['CC-200', 'CC-100']);
      expect(rows.first.net.opex, const Duration(hours: 4));
      expect(rows.last.net.capex, const Duration(hours: 1));

      // Projects, tasks, categories and attributes are four views of the same
      // hours, so every table must sum to the same total.
      Duration sum(List<TimesheetRow> rows) =>
          rows.fold<Duration>(Duration.zero, (a, r) => a + r.net.total);

      expect(sum(data.projectRows), data.total.net.total);
      expect(sum(data.taskRows), data.total.net.total);
      expect(sum(rows), data.total.net.total);
      expect(sum(data.categoryRows), data.total.net.total);
    });

    test('sinks sessions with no value into a trailing Unspecified row', () {
      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: coding,
            gross: const Duration(hours: 8),
          ),
          record(
            id: 's2',
            proj: apollo,
            cat: coding,
            gross: const Duration(hours: 1),
            attributes: {costCentre.id: 'CC-100'},
          ),
        ],
        definitions: [costCentre],
      );

      final rows = data.attributeSections.single.rows;
      // Last despite holding the most hours: it is the gap to go and fill,
      // not the headline.
      expect(rows.map((r) => r.label), ['CC-100', timesheetUnspecifiedLabel]);
      expect(rows.last.net.capex, const Duration(hours: 8));
    });

    test('ignores attributes the user excluded from reporting', () {
      final hidden = definition('def-hidden', 'Internal', reportable: false);
      final disabled = definition('def-off', 'Retired', enabled: false);

      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: coding,
            gross: const Duration(hours: 1),
            attributes: {hidden.id: 'X', disabled.id: 'Y'},
          ),
        ],
        definitions: [hidden, disabled],
      );

      expect(data.attributeSections, isEmpty);
    });

    test('orders attribute sections by their configured display order', () {
      final second = definition('def-b', 'Beta', displayOrder: 2);
      final first = definition('def-a', 'Alpha', displayOrder: 1);

      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: coding,
            gross: const Duration(hours: 1),
            attributes: {first.id: 'A', second.id: 'B'},
          ),
        ],
        definitions: [second, first],
      );

      expect(
        data.attributeSections.map((s) => s.definition.name),
        ['Alpha', 'Beta'],
      );
    });

    test('an empty range produces an empty sheet rather than zeroed tables',
        () {
      final data = service.build(
        range: range,
        records: const [],
        definitions: [costCentre],
      );

      expect(data.isEmpty, isTrue);
      expect(data.codeRows, isEmpty);
      expect(data.projectRows, isEmpty);
      expect(data.taskRows, isEmpty);
      expect(data.categoryRows, isEmpty);
      expect(data.attributeSections, isEmpty);
      expect(data.total.net.total, Duration.zero);
      expect(data.total.net.capexShare, 0);
    });

    test('two releases of one project produce two distinct code rows', () {
      final lwaste = Project(
        id: 'proj-lwaste',
        workspaceId: 'ws-1',
        name: 'L-Waste',
        timesheetCode: 'DEFAULT-CODE',
        codeAttributeDefinitionId: 'attr-release',
        createdAt: now,
        updatedAt: now,
      );

      final resolver = TimesheetCodeResolver(
        codesByProject: {
          'proj-lwaste': {
            'opt-r241': 'LWASTE-241',
            'opt-r242': 'LWASTE-242',
          },
        },
        optionsById: {
          'opt-r241': AttributeOption(
            id: 'opt-r241',
            attributeDefinitionId: 'attr-release',
            label: 'R24.1',
            value: 'r24.1',
            displayOrder: 0,
            createdAt: now,
          ),
          'opt-r242': AttributeOption(
            id: 'opt-r242',
            attributeDefinitionId: 'attr-release',
            label: 'R24.2',
            value: 'r24.2',
            displayOrder: 1,
            createdAt: now,
          ),
        },
      );

      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: lwaste,
            cat: coding,
            gross: const Duration(hours: 3),
            optionIds: {
              'attr-release': ['opt-r241'],
            },
          ),
          record(
            id: 's2',
            proj: lwaste,
            cat: coding,
            gross: const Duration(hours: 2),
            optionIds: {
              'attr-release': ['opt-r242'],
            },
          ),
        ],
        definitions: const [],
        codes: resolver,
      );

      expect(data.codeRows, hasLength(2));
      expect(data.codeRows.map((r) => r.code), ['LWASTE-241', 'LWASTE-242']);
      expect(data.codeRows[0].net.total, const Duration(hours: 3));
      expect(data.codeRows[1].net.total, const Duration(hours: 2));

      // Project table still groups both under L-Waste
      expect(data.projectRows, hasLength(1));
      expect(data.projectRows.single.net.total, const Duration(hours: 5));
    });

    test(
        'two projects sharing one code roll into a single row with two contributions',
        () {
      final projA = Project(
        id: 'proj-a',
        workspaceId: 'ws-1',
        name: 'Alpha Project',
        timesheetCode: 'SHARED-100',
        createdAt: now,
        updatedAt: now,
      );
      final projB = Project(
        id: 'proj-b',
        workspaceId: 'ws-1',
        name: 'Beta Project',
        timesheetCode: 'SHARED-100',
        createdAt: now,
        updatedAt: now,
      );

      const resolver = TimesheetCodeResolver();

      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: projA,
            cat: coding,
            gross: const Duration(hours: 4),
          ),
          record(
            id: 's2',
            proj: projB,
            cat: coding,
            gross: const Duration(hours: 2),
          ),
        ],
        definitions: const [],
        codes: resolver,
      );

      expect(data.codeRows, hasLength(1));
      final sharedRow = data.codeRows.single;
      expect(sharedRow.code, equals('SHARED-100'));
      expect(sharedRow.net.total, equals(const Duration(hours: 6)));
      expect(sharedRow.contributions, hasLength(2));
      expect(sharedRow.contributions[0].projectName, equals('Alpha Project'));
      expect(sharedRow.contributions[0].net.total,
          equals(const Duration(hours: 4)));
      expect(sharedRow.contributions[1].projectName, equals('Beta Project'));
      expect(sharedRow.contributions[1].net.total,
          equals(const Duration(hours: 2)));
    });

    test('codeRows sum to total on both net and gross (invariant)', () {
      final proj = Project(
        id: 'proj-1',
        workspaceId: 'ws-1',
        name: 'Main App',
        timesheetCode: 'MAIN-1',
        createdAt: now,
        updatedAt: now,
      );

      const resolver = TimesheetCodeResolver();

      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: proj,
            cat: coding,
            gross: const Duration(hours: 5),
            idle: const Duration(hours: 1),
            task: FinancialClassification.capex,
          ),
          record(
            id: 's2',
            proj: proj,
            cat: meetings,
            gross: const Duration(hours: 3),
            idle: const Duration(minutes: 30),
            task: FinancialClassification.opex,
          ),
          record(
            id: 's3',
            proj: null,
            cat: null,
            gross: const Duration(hours: 2),
            task: FinancialClassification.none,
          ),
        ],
        definitions: const [],
        codes: resolver,
      );

      final codeRowsNetSum = data.codeRows.fold<ClassificationSplit>(
        ClassificationSplit.zero,
        (sum, r) => sum + r.net,
      );
      final codeRowsGrossSum = data.codeRows.fold<ClassificationSplit>(
        ClassificationSplit.zero,
        (sum, r) => sum + r.gross,
      );

      expect(codeRowsNetSum, equals(data.total.net));
      expect(codeRowsGrossSum, equals(data.total.gross));
    });

    test('the uncodeable row sorts last regardless of size', () {
      final codedProj = Project(
        id: 'proj-coded',
        workspaceId: 'ws-1',
        name: 'Coded',
        timesheetCode: 'CODE-1',
        createdAt: now,
        updatedAt: now,
      );

      const resolver = TimesheetCodeResolver();

      final data = service.build(
        range: range,
        records: [
          // Small coded session
          record(
            id: 's1',
            proj: codedProj,
            cat: coding,
            gross: const Duration(hours: 1),
          ),
          // Large uncoded session
          record(
            id: 's2',
            proj: null,
            cat: null,
            gross: const Duration(hours: 10),
          ),
        ],
        definitions: const [],
        codes: resolver,
      );

      expect(data.codeRows, hasLength(2));
      expect(data.codeRows.first.code, equals('CODE-1'));
      expect(data.codeRows.last.label, equals(timesheetNoCodeLabel));
      expect(data.codeRows.last.gross.total, equals(const Duration(hours: 10)));
    });

    test('task rows borrow code from resolution instead of project default',
        () {
      final lwaste = Project(
        id: 'proj-lwaste',
        workspaceId: 'ws-1',
        name: 'L-Waste',
        timesheetCode: 'DEFAULT-CODE',
        codeAttributeDefinitionId: 'attr-release',
        createdAt: now,
        updatedAt: now,
      );

      const resolver = TimesheetCodeResolver(
        codesByProject: {
          'proj-lwaste': {
            'opt-r241': 'LWASTE-241',
          },
        },
      );

      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: lwaste,
            taskId: 'task-1',
            taskName: 'Task with release',
            gross: const Duration(hours: 2),
            optionIds: {
              'attr-release': ['opt-r241'],
            },
          ),
        ],
        definitions: const [],
        codes: resolver,
      );

      expect(data.taskRows.single.code, equals('LWASTE-241'));
    });
  });
}
