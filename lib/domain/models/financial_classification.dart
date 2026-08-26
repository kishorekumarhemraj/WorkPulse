/// How time is treated by finance: is it building an asset, or running one?
///
/// This lives on the WorkItem rather than the Category because the two answer
/// different questions. A category names the *kind* of work — coding, a
/// meeting, triage — and the same kind of work can be capitalizable on one
/// piece of work and not on another: a design meeting about a new feature is
/// capital, the same meeting about last week's outage is not. What decides it
/// is the *purpose of the task*, which is exactly what a WorkItem is.
enum FinancialClassification {
  capex('CAPEX', 'CapEx', 'Capitalizable — building something new'),
  opex('OPEX', 'OpEx', 'Operational — running what exists'),

  /// Deliberately unclassified, and reported as such.
  ///
  /// Not an error state and not a silent default dressed up as a choice: work
  /// that finance does not split, or that the user has not decided about yet,
  /// has somewhere honest to sit. It is what the Time Sheet shows as the gap
  /// still to be closed.
  none('NONE', 'None', 'Not financially classified');

  /// How the value is stored in SQLite.
  final String value;

  /// The label used in badges, tables and radio buttons.
  final String label;

  /// The longer gloss shown where there is room for it.
  final String description;

  const FinancialClassification(this.value, this.label, this.description);

  /// Whether this classification claims any financial treatment at all.
  bool get isClassified => this != FinancialClassification.none;

  /// Parses a stored value, falling back to [FinancialClassification.none].
  ///
  /// `none` is the fallback rather than an operational default: an
  /// unreadable value must never quietly become a claim about capitalizable
  /// work.
  static FinancialClassification fromString(String? value) {
    if (value == null) return FinancialClassification.none;
    return FinancialClassification.values.firstWhere(
      (e) => e.value.toUpperCase() == value.toUpperCase(),
      orElse: () => FinancialClassification.none,
    );
  }
}
