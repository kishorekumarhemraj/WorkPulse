import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/domain/models/financial_classification.dart';

/// How a [FinancialClassification] is drawn, in one place.
///
/// The enum itself lives in `domain/` and so cannot name a Flutter type; this
/// is where the icon and colour for each value are decided, so the task form,
/// the session editor and the Time Sheet cannot drift into showing the same
/// classification three different ways.
extension FinancialClassificationStyle on FinancialClassification {
  IconData get icon => switch (this) {
        FinancialClassification.capex => Icons.trending_up,
        FinancialClassification.opex => Icons.autorenew,
        FinancialClassification.none => Icons.remove_circle_outline,
      };

  /// The role colour. Always paired with the label — never the only signal.
  Color colorOf(BuildContext context) {
    final colors = context.colors;
    return switch (this) {
      FinancialClassification.capex => colors.accent,
      FinancialClassification.opex => colors.warning,
      FinancialClassification.none => colors.textTertiary,
    };
  }
}
