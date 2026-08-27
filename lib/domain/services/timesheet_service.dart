import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/domain/services/timesheet_grid_math.dart';

/// The label a row carries when a session has no value for the attribute
/// the table is breaking down.
const String timesheetUnspecifiedLabel = 'Unspecified';
const String timesheetNoCodeLabel = 'No timesheet code';

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
    TimesheetCodeResolver codes = const TimesheetCodeResolver(),
    TimesheetHoursBasis basis = TimesheetHoursBasis.net,
    int weekStartDay = DateTime.saturday,
    double roundingIncrement = 0.25,
  }) {
    final total = _RowBuilder(id: '__total__', label: 'Total');
    final codeRows = <String, _CodeRowBuilder>{};
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

      final resolution = codes.resolveFor(
        project: record.project,
        attributeOptionIds: record.attributeOptionIds,
      );

      final codeKey = resolution.code?.trim().isNotEmpty == true
          ? resolution.code!.trim()
          : '';
      final codeLabel = codeKey.isNotEmpty ? codeKey : timesheetNoCodeLabel;

      final projectId = record.project?.id ?? record.workItem.projectId;
      final projectName = record.project?.name ?? 'Unknown Project';

      codeRows
          .putIfAbsent(
            codeKey,
            () => _CodeRowBuilder(code: codeKey, label: codeLabel),
          )
          .add(
            classification: classification,
            net: net,
            gross: gross,
            projectId: projectId,
            projectName: projectName,
            optionLabel: resolution.optionLabel,
            source: resolution.source,
          );

      projects
          .putIfAbsent(
            projectId,
            () => _RowBuilder(
              id: projectId,
              label: projectName,
              colorHex: record.project?.colorHex,
              code: record.project?.timesheetCode,
            ),
          )
          .add(classification, net: net, gross: gross);

      // Task rows borrow their code from resolution, not from the project record (F2)
      tasks
          .putIfAbsent(
            record.workItem.id,
            () => _RowBuilder(
              id: record.workItem.id,
              label: record.workItem.name,
              colorHex: record.project?.colorHex,
              code: resolution.code,
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

        final optionIds = record.attributeOptionIds[def.id];
        final rowKey = (def.type == AttributeType.singleSelect &&
                optionIds != null &&
                optionIds.isNotEmpty)
            ? optionIds.first
            : label;

        attributeRows[def.id]!
            .putIfAbsent(rowKey, () => _RowBuilder(id: rowKey, label: label))
            .add(classification, net: net, gross: gross);
      }
    }

    final weekBlocks = <TimesheetWeek>[];
    var weeksTruncated = false;

    if (records.isNotEmpty) {
      final rangeStartLocal = range.start.toLocal();
      final rangeEndLocal = range.end.toLocal();
      var currentWeekStart = weekStartFor(rangeStartLocal, weekStartDay);

      while (currentWeekStart.isBefore(rangeEndLocal) ||
          currentWeekStart.isAtSameMomentAs(rangeEndLocal)) {
        final days = <DateTime>[
          for (var i = 0; i < 7; i++)
            DateTime(currentWeekStart.year, currentWeekStart.month,
                currentWeekStart.day + i),
        ];
        final nextWeekStart = DateTime(
          currentWeekStart.year,
          currentWeekStart.month,
          currentWeekStart.day + 7,
        );

        final gridRowBuilders = <String, _GridRowBuilder>{};

        for (final record in records) {
          final sessionStartLocal = record.session.startTime.toLocal();
          final sessionEndLocal = (record.session.endTime ??
                  record.session.startTime.add(record.grossDuration))
              .toLocal();

          if (sessionEndLocal.isBefore(currentWeekStart) ||
              sessionStartLocal.isAfter(nextWeekStart) ||
              sessionStartLocal.isAtSameMomentAs(nextWeekStart)) {
            continue;
          }

          final resolution = codes.resolveFor(
            project: record.project,
            attributeOptionIds: record.attributeOptionIds,
          );

          final codeKey = resolution.code?.trim().isNotEmpty == true
              ? resolution.code!.trim()
              : '';
          final codeLabel = codeKey.isNotEmpty ? codeKey : timesheetNoCodeLabel;
          final classification = record.classification;
          final rowKey = '$codeKey:${classification.name}';

          for (var dayIdx = 0; dayIdx < 7; dayIdx++) {
            final day = days[dayIdx];
            final grossOnDay =
                overlapOnDay(sessionStartLocal, sessionEndLocal, day);
            if (grossOnDay <= Duration.zero) continue;

            var idleOnDay = Duration.zero;
            for (final idle in record.idlePeriods) {
              if (idle.resolution != IdleResolution.markIdle) continue;
              final idleStartLocal = idle.startTime.toLocal();
              final idleEndLocal = (idle.endTime ??
                      idle.startTime.add(idle.duration))
                  .toLocal();
              idleOnDay += overlapOnDay(idleStartLocal, idleEndLocal, day);
            }

            final netOnDay =
                grossOnDay > idleOnDay ? grossOnDay - idleOnDay : Duration.zero;
            final dayDuration =
                basis == TimesheetHoursBasis.net ? netOnDay : grossOnDay;

            if (dayDuration > Duration.zero) {
              gridRowBuilders
                  .putIfAbsent(
                    rowKey,
                    () => _GridRowBuilder(
                      code: codeKey,
                      codeLabel: codeLabel,
                      classification: classification,
                      projectName: record.project?.name,
                      optionLabel: resolution.optionLabel,
                      needsAttention: resolution.needsAttention,
                    ),
                  )
                  .add(
                    dayIdx,
                    dayDuration,
                    projectName: record.project?.name,
                    optionLabel: resolution.optionLabel,
                    needsAttention: resolution.needsAttention,
                  );
            }
          }
        }

        final sortedRows =
            _sortedGridRows(gridRowBuilders.values, roundingIncrement);
        if (sortedRows.isNotEmpty) {
          if (weekBlocks.length >= maxTimesheetWeeks) {
            weeksTruncated = true;
            break;
          }

          final dailyTotals = List<double>.generate(7, (col) {
            return sumCells(sortedRows.map((r) => r.cells[col]));
          });
          final weekTotal = sumCells(dailyTotals);
          final exactWeekTotal =
              sortedRows.fold(Duration.zero, (a, b) => a + b.exactTotal);

          weekBlocks.add(TimesheetWeek(
            start: days.first,
            days: days,
            rows: sortedRows,
            dailyTotals: dailyTotals,
            total: weekTotal,
            exactTotal: exactWeekTotal,
          ));
        }

        currentWeekStart = nextWeekStart;
      }
    }

    return TimesheetData(
      range: range,
      total: total.build(),
      codeRows: _sortedCodeRows(codeRows.values),
      weeks: weekBlocks,
      weeksTruncated: weeksTruncated,
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

  static List<TimesheetCodeRow> _sortedCodeRows(
      Iterable<_CodeRowBuilder> builders) {
    final rows = builders.map((b) => b.build()).toList()
      ..sort((a, b) {
        final byDuration = b.gross.total.compareTo(a.gross.total);
        return byDuration != 0 ? byDuration : a.label.compareTo(b.label);
      });
    final uncodeable = rows
        .where((r) => r.code.isEmpty || r.label == timesheetNoCodeLabel)
        .toList();
    if (uncodeable.isEmpty) return rows;
    return [
      ...rows
          .where((r) => r.code.isNotEmpty && r.label != timesheetNoCodeLabel),
      ...uncodeable,
    ];
  }

  static List<TimesheetGridRow> _sortedGridRows(
      Iterable<_GridRowBuilder> builders, double increment) {
    final rows = builders.map((b) => b.build(increment)).toList()
      ..sort((a, b) {
        final codeA = a.code.trim();
        final codeB = b.code.trim();
        final aIsUncodeable =
            codeA.isEmpty || a.codeLabel == timesheetNoCodeLabel;
        final bIsUncodeable =
            codeB.isEmpty || b.codeLabel == timesheetNoCodeLabel;

        if (aIsUncodeable != bIsUncodeable) {
          return aIsUncodeable ? 1 : -1;
        }

        final codeCompare = codeA.compareTo(codeB);
        if (codeCompare != 0) return codeCompare;

        return a.classification.index.compareTo(b.classification.index);
      });
    return rows;
  }
}

class _GridRowBuilder {
  final String code;
  final String codeLabel;
  final FinancialClassification classification;
  String? projectName;
  String? optionLabel;
  bool needsAttention;
  final List<Duration> exactCells;

  _GridRowBuilder({
    required this.code,
    required this.codeLabel,
    required this.classification,
    this.projectName,
    this.optionLabel,
    this.needsAttention = false,
  }) : exactCells = List<Duration>.filled(7, Duration.zero);

  void add(
    int dayIndex,
    Duration duration, {
    String? projectName,
    String? optionLabel,
    bool needsAttention = false,
  }) {
    exactCells[dayIndex] += duration;
    if (projectName != null && this.projectName == null) {
      this.projectName = projectName;
    }
    if (optionLabel != null && this.optionLabel == null) {
      this.optionLabel = optionLabel;
    }
    if (needsAttention) {
      this.needsAttention = true;
    }
  }

  Duration get exactTotal => exactCells.fold(Duration.zero, (a, b) => a + b);

  TimesheetGridRow build(double roundingIncrement) {
    final cells =
        exactCells.map((d) => roundCell(d, roundingIncrement)).toList();
    return TimesheetGridRow(
      code: code,
      codeLabel: codeLabel,
      classification: classification,
      cells: cells,
      total: sumCells(cells),
      exactTotal: exactTotal,
      projectName: projectName,
      optionLabel: optionLabel,
      needsAttention: needsAttention,
    );
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

class _ContributionBuilder {
  final String projectId;
  final String projectName;
  final String? optionLabel;
  final TimesheetCodeSource source;
  ClassificationSplit _net = ClassificationSplit.zero;
  ClassificationSplit _gross = ClassificationSplit.zero;

  _ContributionBuilder({
    required this.projectId,
    required this.projectName,
    this.optionLabel,
    required this.source,
  });

  void add(
    FinancialClassification classification, {
    required Duration net,
    required Duration gross,
  }) {
    _net = _net.plus(classification, net);
    _gross = _gross.plus(classification, gross);
  }

  TimesheetCodeContribution build() => TimesheetCodeContribution(
        projectId: projectId,
        projectName: projectName,
        optionLabel: optionLabel,
        source: source,
        net: _net,
        gross: _gross,
      );
}

class _CodeRowBuilder {
  final String code;
  final String label;
  ClassificationSplit _net = ClassificationSplit.zero;
  ClassificationSplit _gross = ClassificationSplit.zero;
  int _sessionCount = 0;
  final Map<String, _ContributionBuilder> _contributions = {};

  _CodeRowBuilder({
    required this.code,
    required this.label,
  });

  void add({
    required FinancialClassification classification,
    required Duration net,
    required Duration gross,
    required String projectId,
    required String projectName,
    required String? optionLabel,
    required TimesheetCodeSource source,
  }) {
    _net = _net.plus(classification, net);
    _gross = _gross.plus(classification, gross);
    _sessionCount++;

    final contribKey = '$projectId:${optionLabel ?? ''}:${source.name}';
    _contributions
        .putIfAbsent(
          contribKey,
          () => _ContributionBuilder(
            projectId: projectId,
            projectName: projectName,
            optionLabel: optionLabel,
            source: source,
          ),
        )
        .add(classification, net: net, gross: gross);
  }

  TimesheetCodeRow build() {
    final sortedContributions =
        _contributions.values.map((c) => c.build()).toList()
          ..sort((a, b) {
            final byGross = b.gross.total.compareTo(a.gross.total);
            if (byGross != 0) return byGross;
            return a.projectName.compareTo(b.projectName);
          });

    return TimesheetCodeRow(
      code: code,
      label: label,
      net: _net,
      gross: _gross,
      sessionCount: _sessionCount,
      contributions: sortedContributions,
    );
  }
}
