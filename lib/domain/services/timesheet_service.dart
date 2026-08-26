import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';
import 'package:workpulse/domain/services/export_service.dart';

/// The label a row carries when a session has no value for the attribute
/// the table is breaking down.
const String timesheetUnspecifiedLabel = 'Unspecified';

/// Turns the session records already loaded for a range into the CAPEX/OPEX
/// tables the Time Sheet renders.
///
/// Pure by design, like the work-pattern scan: records in, tables out. It owns
/// no repositories and no clock, so every figure it reports is derived from
/// the records it was handed and nothing else.
///
/// A session's own category decides its CAPEX/OPEX bucket — never the parent
/// work item's (AGENTS.md rule 7). Time on a session the user left
/// unclassified is carried in [CapexOpexSplit.unclassified] rather than
/// dropped or guessed at, so every table sums to the hours actually tracked.
class TimesheetService {
  const TimesheetService();

  TimesheetData build({
    required DateRange range,
    required List<SessionExportRecord> records,
    required List<AttributeDefinition> definitions,
  }) {
    final total = _RowBuilder(id: '__total__', label: 'Total');
    final projects = <String, _RowBuilder>{};

    // Only attributes the user marked reportable, and only live ones. This
    // is the same filter the dashboard's attribute breakdowns apply, so the
    // two screens never disagree about which fields are worth reporting on.
    final reportableDefs = definitions
        .where((d) => d.reportable && d.enabled && !d.isArchived)
        .toList()
      ..sort((a, b) {
        final byOrder = a.displayOrder.compareTo(b.displayOrder);
        return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
      });

    final attributeRows = <String, Map<String, _RowBuilder>>{
      for (final def in reportableDefs) def.id: <String, _RowBuilder>{},
    };

    for (final record in records) {
      final type = record.category?.type;
      final net = record.netActiveDuration;
      final gross = record.grossDuration;

      total.add(type, net: net, gross: gross);

      final projectId = record.project?.id ?? record.workItem.projectId;
      projects
          .putIfAbsent(
            projectId,
            () => _RowBuilder(
              id: projectId,
              label: record.project?.name ?? 'Unknown Project',
              colorHex: record.project?.colorHex,
            ),
          )
          .add(type, net: net, gross: gross);

      for (final def in reportableDefs) {
        // A multi-select value arrives pre-joined ("Backend; Platform") and
        // is kept whole rather than split across a row per option. Splitting
        // would count the same hour once per option, and a timesheet whose
        // rows do not sum to its total is worse than a coarse one.
        final raw = record.attributeValues[def.id]?.trim();
        final label =
            raw == null || raw.isEmpty ? timesheetUnspecifiedLabel : raw;

        attributeRows[def.id]!
            .putIfAbsent(label, () => _RowBuilder(id: label, label: label))
            .add(type, net: net, gross: gross);
      }
    }

    return TimesheetData(
      range: range,
      total: total.build(),
      projectRows: _sorted(projects.values),
      attributeSections: [
        for (final def in reportableDefs)
          if (attributeRows[def.id]!.isNotEmpty)
            TimesheetAttributeSection(
              definition: def,
              rows: _sorted(attributeRows[def.id]!.values),
            ),
      ],
      sessionCount: records.length,
    );
  }

  /// Longest first, so the rows that dominate a timesheet are the ones the
  /// user sees without scrolling. Ties fall back to the label so the order is
  /// stable between rebuilds.
  ///
  /// Ranked on gross rather than the selected basis: flipping the Net/Gross
  /// toggle should change the figures in the table, not reshuffle its rows
  /// under the reader's eye.
  static List<TimesheetRow> _sorted(Iterable<_RowBuilder> builders) {
    final rows = builders.map((b) => b.build()).toList()
      ..sort((a, b) {
        final byDuration = b.gross.total.compareTo(a.gross.total);
        return byDuration != 0 ? byDuration : a.label.compareTo(b.label);
      });
    // "Unspecified" is the absence of a value, not the largest one. It sits
    // last however much time it holds, so it reads as the gap to go and fill.
    final unspecified =
        rows.where((r) => r.label == timesheetUnspecifiedLabel).toList();
    if (unspecified.isEmpty) return rows;
    return [
      ...rows.where((r) => r.label != timesheetUnspecifiedLabel),
      ...unspecified,
    ];
  }
}

/// Mutable accumulator behind one [TimesheetRow].
class _RowBuilder {
  final String id;
  final String label;
  final String? colorHex;

  CapexOpexSplit _net = CapexOpexSplit.zero;
  CapexOpexSplit _gross = CapexOpexSplit.zero;
  int _sessionCount = 0;

  _RowBuilder({required this.id, required this.label, this.colorHex});

  void add(
    CategoryType? type, {
    required Duration net,
    required Duration gross,
  }) {
    _net = _net.plus(type, net);
    _gross = _gross.plus(type, gross);
    _sessionCount++;
  }

  TimesheetRow build() => TimesheetRow(
        id: id,
        label: label,
        colorHex: colorHex,
        net: _net,
        gross: _gross,
        sessionCount: _sessionCount,
      );
}
