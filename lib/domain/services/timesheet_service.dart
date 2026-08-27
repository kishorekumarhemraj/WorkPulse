import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
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
/// The CapEx/OpEx bucket comes from the task, or from the session where one
/// overrides it — resolved upstream in [SessionExportRecord.classification],
/// so this service never has to know which of the two spoke. Time nobody has
/// classified is carried in [ClassificationSplit.none] rather than dropped or
/// guessed at, so every table sums to the hours actually tracked.
class TimesheetService {
  const TimesheetService();

  TimesheetData build({
    required DateRange range,
    required List<SessionExportRecord> records,
    required List<AttributeDefinition> definitions,
  }) {
    final total = _RowBuilder(id: '__total__', label: 'Total');
    final projects = <String, _RowBuilder>{};
    final tasks = <String, _RowBuilder>{};

    // Categories, keyed by classification then by category. This is the
    // "coding versus meetings inside CapEx" question, which only became
    // askable once the classification stopped being the category.
    final categoriesByClassification =
        <FinancialClassification, Map<String, _RowBuilder>>{
      for (final value in FinancialClassification.values)
        value: <String, _RowBuilder>{},
    };

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
      final classification = record.classification;
      final net = record.netActiveDuration;
      final gross = record.grossDuration;

      total.add(classification, net: net, gross: gross);

      final projectId = record.project?.id ?? record.workItem.projectId;
      projects
          .putIfAbsent(
            projectId,
            () => _RowBuilder(
              id: projectId,
              label: record.project?.name ?? 'Unknown Project',
              colorHex: record.project?.colorHex,
              code: record.project?.timesheetCode,
            ),
          )
          .add(classification, net: net, gross: gross);

      tasks
          .putIfAbsent(
            record.workItem.id,
            () => _RowBuilder(
              id: record.workItem.id,
              label: record.workItem.name,
              colorHex: record.project?.colorHex,
              code: record.project?.timesheetCode,
            ),
          )
          .add(classification, net: net, gross: gross);

      // A session's own category, never the task's — the kind of work
      // genuinely varies session to session, which is exactly why rule 7
      // still holds for it.
      final categoryId = record.category?.id ?? _uncategorisedKey;
      final categoryName = record.category?.name ?? 'Uncategorized';
      categoriesByClassification[classification]!
          .putIfAbsent(
            categoryId,
            () => _RowBuilder(id: categoryId, label: categoryName),
          )
          .add(classification, net: net, gross: gross);

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
            .add(classification, net: net, gross: gross);
      }
    }

    return TimesheetData(
      range: range,
      total: total.build(),
      projectRows: _sorted(projects.values),
      taskRows: _sorted(tasks.values),
      categorySections: [
        for (final value in FinancialClassification.values)
          if (categoriesByClassification[value]!.isNotEmpty)
            ClassificationCategorySection(
              classification: value,
              rows: _sorted(categoriesByClassification[value]!.values),
            ),
      ],
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
/// The key uncategorised time is grouped under. A real category id is a
/// UUID, so this cannot collide with one.
const String _uncategorisedKey = '__uncategorised__';

class _RowBuilder {
  final String id;
  final String label;
  final String? colorHex;
  final String? code;

  ClassificationSplit _net = ClassificationSplit.zero;
  ClassificationSplit _gross = ClassificationSplit.zero;
  int _sessionCount = 0;

  _RowBuilder({
    required this.id,
    required this.label,
    this.colorHex,
    this.code,
  });

  void add(
    FinancialClassification classification, {
    required Duration net,
    required Duration gross,
  }) {
    _net = _net.plus(classification, net);
    _gross = _gross.plus(classification, gross);
    _sessionCount++;
  }

  TimesheetRow build() => TimesheetRow(
        id: id,
        label: label,
        colorHex: colorHex,
        code: code,
        net: _net,
        gross: _gross,
        sessionCount: _sessionCount,
      );
}
