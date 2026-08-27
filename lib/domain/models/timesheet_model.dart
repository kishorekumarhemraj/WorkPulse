import 'package:equatable/equatable.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';

/// Which duration the Time Sheet reports.
///
/// Both are offered because they answer different questions. Net is what the
/// user actually worked and is what the rest of WorkPulse reports. Gross is
/// wall-clock desk time, which is usually what reconciles against a
/// contractual week — so the number an employer's timesheet expects and the
/// number the user actually worked are both one toggle away.
enum TimesheetHoursBasis {
  net('Net', 'Idle time excluded'),
  gross('Gross', 'Wall-clock, idle included');

  final String label;
  final String description;

  const TimesheetHoursBasis(this.label, this.description);
}

/// Time split by [FinancialClassification].
///
/// Every bucket is carried, `none` included, so a row always sums to the
/// hours actually tracked. A gap between a total and its CapEx + OpEx reads
/// as work waiting to be classified, which is a thing the user can act on;
/// silently dropping it would just make the sheet wrong.
class ClassificationSplit extends Equatable {
  final Duration capex;
  final Duration opex;
  final Duration none;

  const ClassificationSplit({
    this.capex = Duration.zero,
    this.opex = Duration.zero,
    this.none = Duration.zero,
  });

  static const ClassificationSplit zero = ClassificationSplit();

  Duration get total => capex + opex + none;

  /// The classified part only — the denominator for a CapEx ratio that is
  /// not diluted by hours nobody has decided about yet.
  Duration get classifiedTotal => capex + opex;

  bool get hasNone => none > Duration.zero;

  /// CapEx as a percentage of classified time, 0–100. Zero when nothing is
  /// classified yet, rather than a division by zero.
  double get capexShare => _share(capex);

  /// OpEx as a percentage of classified time, 0–100.
  double get opexShare => _share(opex);

  double _share(Duration part) {
    final base = classifiedTotal.inSeconds;
    if (base <= 0) return 0;
    return (part.inSeconds / base * 100).clamp(0.0, 100.0);
  }

  Duration forClassification(FinancialClassification classification) =>
      switch (classification) {
        FinancialClassification.capex => capex,
        FinancialClassification.opex => opex,
        FinancialClassification.none => none,
      };

  ClassificationSplit plus(
    FinancialClassification classification,
    Duration duration,
  ) {
    return switch (classification) {
      FinancialClassification.capex => ClassificationSplit(
          capex: capex + duration,
          opex: opex,
          none: none,
        ),
      FinancialClassification.opex => ClassificationSplit(
          capex: capex,
          opex: opex + duration,
          none: none,
        ),
      FinancialClassification.none => ClassificationSplit(
          capex: capex,
          opex: opex,
          none: none + duration,
        ),
    };
  }

  ClassificationSplit operator +(ClassificationSplit other) =>
      ClassificationSplit(
        capex: capex + other.capex,
        opex: opex + other.opex,
        none: none + other.none,
      );

  @override
  List<Object?> get props => [capex, opex, none];
}

/// One line of a Time Sheet table — a project, or one value of one attribute.
///
/// Both bases are carried so the Net/Gross toggle is a repaint rather than a
/// re-query; the range is already in memory when the split is computed.
class TimesheetRow extends Equatable {
  final String id;
  final String label;
  final String? colorHex;

  /// The project's timesheet code, where the row is a project. Null on
  /// attribute rows, which are not booked against anything themselves.
  final String? code;

  final ClassificationSplit net;
  final ClassificationSplit gross;
  final int sessionCount;

  const TimesheetRow({
    required this.id,
    required this.label,
    this.colorHex,
    this.code,
    this.net = ClassificationSplit.zero,
    this.gross = ClassificationSplit.zero,
    this.sessionCount = 0,
  });

  ClassificationSplit split(TimesheetHoursBasis basis) =>
      basis == TimesheetHoursBasis.net ? net : gross;

  @override
  List<Object?> get props =>
      [id, label, colorHex, code, net, gross, sessionCount];
}

/// Where this row's hours came from — a code can be fed by more than one
/// project, and by more than one release within a project.
class TimesheetCodeContribution extends Equatable {
  final String projectId;
  final String projectName;
  final String? optionLabel; // the release, where there is one
  final TimesheetCodeSource source;
  final ClassificationSplit net;
  final ClassificationSplit gross;

  const TimesheetCodeContribution({
    required this.projectId,
    required this.projectName,
    this.optionLabel,
    required this.source,
    this.net = ClassificationSplit.zero,
    this.gross = ClassificationSplit.zero,
  });

  TimesheetCodeContribution copyWith({
    String? projectId,
    String? projectName,
    String? optionLabel,
    TimesheetCodeSource? source,
    ClassificationSplit? net,
    ClassificationSplit? gross,
  }) {
    return TimesheetCodeContribution(
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      optionLabel: optionLabel ?? this.optionLabel,
      source: source ?? this.source,
      net: net ?? this.net,
      gross: gross ?? this.gross,
    );
  }

  @override
  List<Object?> get props =>
      [projectId, projectName, optionLabel, source, net, gross];
}

/// One line of the sheet the user actually fills in.
class TimesheetCodeRow extends Equatable {
  /// The code, or '' for the row holding time that could not be coded.
  final String code;
  final String label; // code, or 'No timesheet code'
  final ClassificationSplit net;
  final ClassificationSplit gross;
  final int sessionCount;

  /// Where this row's hours came from — a code can be fed by more than one
  /// project, and by more than one release within a project.
  final List<TimesheetCodeContribution> contributions;

  const TimesheetCodeRow({
    required this.code,
    required this.label,
    this.net = ClassificationSplit.zero,
    this.gross = ClassificationSplit.zero,
    this.sessionCount = 0,
    this.contributions = const [],
  });

  bool get needsAttention => contributions.any((c) => c.source.needsAttention);

  ClassificationSplit split(TimesheetHoursBasis basis) =>
      basis == TimesheetHoursBasis.net ? net : gross;

  @override
  List<Object?> get props =>
      [code, label, net, gross, sessionCount, contributions];
}

/// One attribute's worth of rows — a table per configurable attribute.
class TimesheetAttributeSection extends Equatable {
  final AttributeDefinition definition;
  final List<TimesheetRow> rows;

  const TimesheetAttributeSection({
    required this.definition,
    required this.rows,
  });

  @override
  List<Object?> get props => [definition, rows];
}

/// One classification's worth of category rows — "coding versus meetings"
/// inside CapEx, and again inside OpEx.
///
/// This is the breakdown that the old category-level model could not express:
/// when the category *was* the classification, asking which categories made
/// up CapEx had only one possible answer.
class ClassificationCategorySection extends Equatable {
  final FinancialClassification classification;

  /// Category rows, longest first. Each row's split holds only this
  /// classification's bucket, so a row total is that category's time within
  /// this classification.
  final List<TimesheetRow> rows;

  const ClassificationCategorySection({
    required this.classification,
    required this.rows,
  });

  @override
  List<Object?> get props => [classification, rows];
}

/// Everything the Time Sheet screen renders for one date range.
class TimesheetData extends Equatable {
  final DateRange range;

  /// The grand total across every session in range.
  final TimesheetRow total;

  /// Headline table: time grouped by resolved timesheet code.
  final List<TimesheetCodeRow> codeRows;

  final List<TimesheetRow> projectRows;

  /// Time by task — the level the classification is now set at, so this is
  /// where a wrong CapEx figure gets traced back to.
  final List<TimesheetRow> taskRows;

  /// Categories within each classification, in enum order.
  final List<ClassificationCategorySection> categorySections;

  final List<TimesheetAttributeSection> attributeSections;
  final int sessionCount;

  const TimesheetData({
    required this.range,
    required this.total,
    this.codeRows = const [],
    this.projectRows = const [],
    this.taskRows = const [],
    this.categorySections = const [],
    this.attributeSections = const [],
    this.sessionCount = 0,
  });

  bool get isEmpty => sessionCount == 0;

  @override
  List<Object?> get props => [
        range,
        total,
        codeRows,
        projectRows,
        taskRows,
        categorySections,
        attributeSections,
        sessionCount,
      ];
}
