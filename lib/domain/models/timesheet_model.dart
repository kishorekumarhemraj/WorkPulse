import 'package:equatable/equatable.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/date_range.dart';

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

/// Time split by the CAPEX/OPEX type of the category each session carries.
///
/// [unclassified] is time on sessions with no category at all. Every category
/// has a type, so nothing else can land here — but unclassified time is
/// carried rather than dropped, so a row always sums to the hours actually
/// tracked and a gap reads as work waiting to be classified.
class CapexOpexSplit extends Equatable {
  final Duration capex;
  final Duration opex;
  final Duration unclassified;

  const CapexOpexSplit({
    this.capex = Duration.zero,
    this.opex = Duration.zero,
    this.unclassified = Duration.zero,
  });

  static const CapexOpexSplit zero = CapexOpexSplit();

  Duration get total => capex + opex + unclassified;

  /// The classified part only — the denominator for a CAPEX ratio that is
  /// not diluted by time the user has yet to categorise.
  Duration get classifiedTotal => capex + opex;

  bool get hasUnclassified => unclassified > Duration.zero;

  /// CAPEX as a percentage of classified time, 0–100. Zero when nothing is
  /// classified yet, rather than a division by zero.
  double get capexShare => _share(capex);

  /// OPEX as a percentage of classified time, 0–100.
  double get opexShare => _share(opex);

  double _share(Duration part) {
    final base = classifiedTotal.inSeconds;
    if (base <= 0) return 0;
    return (part.inSeconds / base * 100).clamp(0.0, 100.0);
  }

  /// The portion of this split carried by [type], or [unclassified] when the
  /// session had no category.
  Duration forType(CategoryType? type) => switch (type) {
        CategoryType.capex => capex,
        CategoryType.opex => opex,
        null => unclassified,
      };

  CapexOpexSplit plus(CategoryType? type, Duration duration) {
    return switch (type) {
      CategoryType.capex => CapexOpexSplit(
          capex: capex + duration,
          opex: opex,
          unclassified: unclassified,
        ),
      CategoryType.opex => CapexOpexSplit(
          capex: capex,
          opex: opex + duration,
          unclassified: unclassified,
        ),
      null => CapexOpexSplit(
          capex: capex,
          opex: opex,
          unclassified: unclassified + duration,
        ),
    };
  }

  CapexOpexSplit operator +(CapexOpexSplit other) => CapexOpexSplit(
        capex: capex + other.capex,
        opex: opex + other.opex,
        unclassified: unclassified + other.unclassified,
      );

  @override
  List<Object?> get props => [capex, opex, unclassified];
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

  final CapexOpexSplit net;
  final CapexOpexSplit gross;
  final int sessionCount;

  const TimesheetRow({
    required this.id,
    required this.label,
    this.colorHex,
    this.code,
    this.net = CapexOpexSplit.zero,
    this.gross = CapexOpexSplit.zero,
    this.sessionCount = 0,
  });

  CapexOpexSplit split(TimesheetHoursBasis basis) =>
      basis == TimesheetHoursBasis.net ? net : gross;

  @override
  List<Object?> get props =>
      [id, label, colorHex, code, net, gross, sessionCount];
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

/// Everything the Time Sheet screen renders for one date range.
class TimesheetData extends Equatable {
  final DateRange range;

  /// The grand total across every session in range.
  final TimesheetRow total;

  final List<TimesheetRow> projectRows;
  final List<TimesheetAttributeSection> attributeSections;
  final int sessionCount;

  const TimesheetData({
    required this.range,
    required this.total,
    this.projectRows = const [],
    this.attributeSections = const [],
    this.sessionCount = 0,
  });

  bool get isEmpty => sessionCount == 0;

  @override
  List<Object?> get props => [
        range,
        total,
        projectRows,
        attributeSections,
        sessionCount,
      ];
}
