import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timesheet_service.dart';

void main() {
  final now = DateTime.utc(2026, 8, 24, 9);

  Category category(String id, String name, CategoryType type) => Category(
        id: id,
        workspaceId: 'ws-1',
        name: name,
        type: type,
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

  WorkItem workItem(String id, String projectId) => WorkItem(
        id: id,
        workspaceId: 'ws-1',
        name: 'Task $id',
        projectId: projectId,
        categoryId: 'cat-capex',
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

  SessionExportRecord record({
    required String id,
    required Project? proj,
    required Category? cat,
    required Duration gross,
    Duration idle = Duration.zero,
    Map<String, String> attributes = const {},
  }) {
    final item = workItem('wi-$id', proj?.id ?? 'proj-unknown');
    return SessionExportRecord(
      session: Session(
        id: id,
        workItemId: item.id,
        categoryId: cat?.id,
        startTime: now,
        endTime: now.add(gross),
        createdAt: now,
      ),
      workItem: item,
      project: proj,
      category: cat,
      grossDuration: gross,
      idleDuration: idle,
      netActiveDuration: gross - idle,
      attributeValues: attributes,
    );
  }

  final capex = category('cat-capex', 'Feature Work', CategoryType.capex);
  final opex = category('cat-opex', 'Production Support', CategoryType.opex);
  final apollo = project('proj-apollo', 'Apollo', code: 'PRJ-1042');
  final zephyr = project('proj-zephyr', 'Zephyr');
  final costCentre = definition('def-cc', 'Cost Centre');

  final range = DateRange(start: now, end: now.add(const Duration(days: 1)));

  const service = TimesheetService();

  group('TimesheetService', () {
    test('splits hours by the CAPEX/OPEX type of each session category', () {
      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: capex,
            gross: const Duration(hours: 3),
          ),
          record(
            id: 's2',
            proj: apollo,
            cat: opex,
            gross: const Duration(hours: 1),
          ),
        ],
        definitions: const [],
      );

      expect(data.sessionCount, 2);
      expect(data.total.net.capex, const Duration(hours: 3));
      expect(data.total.net.opex, const Duration(hours: 1));
      expect(data.total.net.unclassified, Duration.zero);
      expect(data.total.net.capexShare, 75);
      expect(data.projectRows, hasLength(1));
      expect(data.projectRows.single.label, 'Apollo');
    });

    test('reports net and gross separately so the toggle needs no re-query',
        () {
      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: capex,
            gross: const Duration(hours: 2),
            idle: const Duration(minutes: 30),
          ),
        ],
        definitions: const [],
      );

      final row = data.projectRows.single;
      expect(row.split(TimesheetHoursBasis.gross).capex,
          const Duration(hours: 2));
      expect(row.split(TimesheetHoursBasis.net).capex,
          const Duration(minutes: 90));
    });

    test('carries uncategorised time rather than dropping or guessing it', () {
      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: null,
            gross: const Duration(hours: 2),
          ),
          record(
            id: 's2',
            proj: apollo,
            cat: capex,
            gross: const Duration(hours: 2),
          ),
        ],
        definitions: const [],
      );

      expect(data.total.net.unclassified, const Duration(hours: 2));
      expect(data.total.net.total, const Duration(hours: 4));
      // The ratio is of classified time, so unclassified hours cannot quietly
      // dilute the CAPEX figure the user reports.
      expect(data.total.net.capexShare, 100);
      expect(data.total.net.hasUnclassified, isTrue);
    });

    test('builds one table per reportable attribute, longest row first', () {
      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: capex,
            gross: const Duration(hours: 1),
            attributes: {costCentre.id: 'CC-100'},
          ),
          record(
            id: 's2',
            proj: zephyr,
            cat: opex,
            gross: const Duration(hours: 4),
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

      // Projects and attributes are two views of the same hours, so both
      // tables must sum to the same total.
      final projectTotal = data.projectRows
          .fold<Duration>(Duration.zero, (sum, r) => sum + r.net.total);
      final attributeTotal =
          rows.fold<Duration>(Duration.zero, (sum, r) => sum + r.net.total);
      expect(projectTotal, attributeTotal);
      expect(projectTotal, data.total.net.total);
    });

    test('sinks sessions with no value into a trailing Unspecified row', () {
      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: capex,
            gross: const Duration(hours: 8),
          ),
          record(
            id: 's2',
            proj: apollo,
            cat: capex,
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
            cat: capex,
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
            cat: capex,
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

    test('project rows carry the timesheet code, attribute rows do not', () {
      final data = service.build(
        range: range,
        records: [
          record(
            id: 's1',
            proj: apollo,
            cat: capex,
            gross: const Duration(hours: 2),
            attributes: {costCentre.id: 'CC-100'},
          ),
          record(
            id: 's2',
            proj: zephyr,
            cat: opex,
            gross: const Duration(hours: 1),
          ),
        ],
        definitions: [costCentre],
      );

      final byId = {for (final r in data.projectRows) r.id: r};
      expect(byId['proj-apollo']!.code, 'PRJ-1042');
      // A project without a code reports it as absent rather than blank, so
      // the Time Sheet can say so out loud.
      expect(byId['proj-zephyr']!.code, isNull);

      // An attribute value is not booked against anything itself.
      expect(
        data.attributeSections.single.rows.every((r) => r.code == null),
        isTrue,
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
      expect(data.attributeSections, isEmpty);
      expect(data.total.net.total, Duration.zero);
      expect(data.total.net.capexShare, 0);
    });
  });
}
