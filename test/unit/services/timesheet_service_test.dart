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

      // Coding versus meetings *within* CapEx — the question the old
      // category-level model could not answer, because the category was the
      // classification.
      final capexSection = data.categorySections
          .firstWhere((s) => s.classification == FinancialClassification.capex);
      expect(capexSection.rows.map((r) => r.label), ['Coding', 'Meetings']);
      expect(capexSection.rows.first.net.capex, const Duration(hours: 5));
      expect(capexSection.rows.last.net.capex, const Duration(hours: 2));

      final opexSection = data.categorySections
          .firstWhere((s) => s.classification == FinancialClassification.opex);
      expect(opexSection.rows.single.label, 'Meetings');
      expect(opexSection.rows.single.net.opex, const Duration(hours: 1));

      // Nothing is unclassified, so that section is absent rather than empty.
      expect(
        data.categorySections
            .any((s) => s.classification == FinancialClassification.none),
        isFalse,
      );
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
      expect(
        data.categorySections
            .fold<Duration>(Duration.zero, (a, s) => a + sum(s.rows)),
        data.total.net.total,
      );
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
      expect(data.projectRows, isEmpty);
      expect(data.taskRows, isEmpty);
      expect(data.categorySections, isEmpty);
      expect(data.attributeSections, isEmpty);
      expect(data.total.net.total, Duration.zero);
      expect(data.total.net.capexShare, 0);
    });
  });
}
