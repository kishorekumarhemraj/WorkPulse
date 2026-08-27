import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/domain/services/timesheet_grid_math.dart';

/// One breakdown section item with an estimated height for column balancing.
class TimesheetSectionItem {
  final Widget widget;
  final int rowCount;
  final double estimatedHeight;

  TimesheetSectionItem({
    required this.widget,
    this.rowCount = 1,
    double? estimatedHeight,
  }) : estimatedHeight = estimatedHeight ?? (80.0 + (rowCount * 36.0));
}

/// Adaptive layout for Time Sheet breakdown sections.
///
/// Lays out sections in 2 balanced columns at or above [Breakpoints.medium] (1000px)
/// using a greedy estimated height pass, and in a single full-width column in
/// original order below [Breakpoints.medium].
class TimesheetSectionColumns extends StatelessWidget {
  final List<TimesheetSectionItem> sections;

  const TimesheetSectionColumns({
    super.key,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn = constraints.maxWidth >= Breakpoints.medium;

        if (!isTwoColumn) {
          // Single-column mode: preserves exact original order
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(height: Spacing.xl),
                sections[i].widget,
              ],
            ],
          );
        }

        // Two-column mode: balanced distribution
        final columns = packIntoTwoColumns<TimesheetSectionItem>(
          sections,
          (s) => s.estimatedHeight,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns[0].length; i++) ...[
                    if (i > 0) const SizedBox(height: Spacing.xl),
                    columns[0][i].widget,
                  ],
                ],
              ),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns[1].length; i++) ...[
                    if (i > 0) const SizedBox(height: Spacing.xl),
                    columns[1][i].widget,
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
