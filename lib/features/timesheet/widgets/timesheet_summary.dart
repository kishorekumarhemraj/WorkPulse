import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/timesheet/widgets/timesheet_table.dart';

/// The headline the Time Sheet exists to deliver: how many hours in range,
/// and how they divide between capitalizable and operational work.
class TimesheetSummary extends StatelessWidget {
  final TimesheetRow total;
  final TimesheetHoursBasis basis;
  final int sessionCount;

  const TimesheetSummary({
    super.key,
    required this.total,
    required this.basis,
    required this.sessionCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final palette = TimesheetPalette.of(context);
    final split = total.split(basis);

    final tiles = <Widget>[
      _SummaryTile(
        label: '${basis.label} Total',
        hours: split.total,
        color: colors.textPrimary,
        caption: '$sessionCount session${sessionCount == 1 ? '' : 's'}',
      ),
      _SummaryTile(
        label: 'CapEx',
        hours: split.capex,
        color: palette.capex,
        caption: '${split.capexShare.round()}% of classified',
      ),
      _SummaryTile(
        label: 'OpEx',
        hours: split.opex,
        color: palette.opex,
        caption: '${split.opexShare.round()}% of classified',
      ),
      if (split.hasNone)
        _SummaryTile(
          label: 'None',
          hours: split.none,
          color: palette.none,
          caption: 'Not financially classified',
        ),
    ];

    // AppCard, not a hand-rolled Container: it is the app's standard content
    // surface, and painting one by hand is how this screen ended up grey —
    // `colors.card` is the inset badge tint, not the card background.
    return AppCard(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Four tiles need room to breathe; below that they stack into
              // two columns rather than squeeze.
              final isNarrow = constraints.maxWidth < Breakpoints.medium;
              final columns = isNarrow ? 2 : 4;
              final gutters = Spacing.lg * (columns - 1);
              final tileWidth = (constraints.maxWidth - gutters) / columns;

              return Wrap(
                spacing: Spacing.lg,
                runSpacing: Spacing.lg,
                children: [
                  for (final tile in tiles)
                    SizedBox(width: tileWidth, child: tile),
                ],
              );
            },
          ),
          const SizedBox(height: Spacing.lg),
          SplitBar(split: split),
          const SizedBox(height: Spacing.sm),
          Text(
            basis.description,
            style:
                theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final Duration hours;
  final Color color;
  final String caption;

  const _SummaryTile({
    required this.label,
    required this.hours,
    required this.color,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final clock = TimerService.formatDuration(
      hours,
      compact: true,
      includeSeconds: false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Spacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatTimesheetHours(hours),
              style: AppTypography.numeric(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: Spacing.xs),
            Text(
              'h',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xxs),
        // The decimal figure above is what gets typed into a timesheet; the
        // clock reading here is what the user recognises as their day.
        Text(
          '$clock · $caption',
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
