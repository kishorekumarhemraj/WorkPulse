import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/classification_style.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/core/widgets/app_snack_bar.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';
import 'package:workpulse/domain/services/timesheet_grid_math.dart';

/// The Timesheet Entry Grid rendered at the top of the Time Sheet screen.
///
/// Lays out weeks in the selected range as 7-day entry grids matching corporate
/// timesheet portals (such as IQVIA PeopleSoft), displaying decimal hours in
/// rounded increments and daily/row totals.
class TimesheetEntryGrid extends StatelessWidget {
  final List<TimesheetWeek> weeks;
  final bool weeksTruncated;
  final TimesheetHoursBasis basis;

  const TimesheetEntryGrid({
    super.key,
    required this.weeks,
    this.weeksTruncated = false,
    this.basis = TimesheetHoursBasis.net,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (weeks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < weeks.length; i++) ...[
          if (i > 0) const SizedBox(height: Spacing.xl),
          _WeekGridCard(week: weeks[i]),
        ],
        if (weeksTruncated) ...[
          const SizedBox(height: Spacing.md),
          _TruncationNotice(maxWeeks: maxTimesheetWeeks, colors: colors),
        ],
      ],
    );
  }
}

class _WeekGridCard extends StatelessWidget {
  final TimesheetWeek week;

  const _WeekGridCard({required this.week});

  static const double _codeWidth = 160;
  static const double _classWidth = 84;
  static const double _dayWidth = 64;
  static const double _totalWidth = 76;
  static const double _minTableWidth = _codeWidth +
      _classWidth +
      (_dayWidth * 7) +
      _totalWidth +
      (Spacing.lg * 2);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final exactHoursStr =
        (week.exactTotal.inSeconds / 3600.0).toStringAsFixed(2);
    final roundedHoursStr = week.total.toStringAsFixed(2);
    final hasRoundingDrift =
        week.exactTotal > Duration.zero && exactHoursStr != roundedHoursStr;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Week Header
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_view_week,
                            size: IconSizes.md,
                            color: colors.accent,
                          ),
                          const SizedBox(width: Spacing.sm),
                          Text(
                            _formatWeekSpan(week.start, week.days.last),
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      if (hasRoundingDrift) ...[
                        const SizedBox(height: Spacing.xxs),
                        Text(
                          'Exact tracked time: $exactHoursStr h '
                          '(portal sum: $roundedHoursStr h)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: Radii.smAll,
                  ),
                  child: Text(
                    '${week.total.toStringAsFixed(2)} h',
                    style: AppTypography.numeric(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                OutlinedButton.icon(
                  onPressed: () => _copyAsTsv(context, week),
                  icon: const Icon(Icons.copy, size: IconSizes.xs),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, ControlSizes.toolbar),
                    textStyle: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),

          // Scrollable Grid Table
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = math.max(constraints.maxWidth, _minTableWidth);

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Header Row
                      _HeaderRow(days: week.days, today: today),
                      Divider(height: 1, color: colors.divider),

                      // Data Rows
                      for (final row in week.rows) ...[
                        _DataRow(
                          row: row,
                          days: week.days,
                          today: today,
                        ),
                        Divider(
                            height: 1,
                            color: colors.divider.withValues(alpha: 0.5)),
                      ],

                      // Totals Row
                      _TotalsRow(week: week, today: today),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _formatWeekSpan(DateTime start, DateTime end) {
    final startStr =
        '${_shortDay(start.weekday)} ${start.day} ${_shortMonth(start.month)}';
    final endStr =
        '${_shortDay(end.weekday)} ${end.day} ${_shortMonth(end.month)}';
    return 'Week of $startStr – $endStr';
  }

  static String _shortDay(int weekday) => switch (weekday) {
        DateTime.monday => 'Mon',
        DateTime.tuesday => 'Tue',
        DateTime.wednesday => 'Wed',
        DateTime.thursday => 'Thu',
        DateTime.friday => 'Fri',
        DateTime.saturday => 'Sat',
        DateTime.sunday => 'Sun',
        _ => '',
      };

  static String _shortMonth(int month) => switch (month) {
        1 => 'Jan',
        2 => 'Feb',
        3 => 'Mar',
        4 => 'Apr',
        5 => 'May',
        6 => 'Jun',
        7 => 'Jul',
        8 => 'Aug',
        9 => 'Sep',
        10 => 'Oct',
        11 => 'Nov',
        12 => 'Dec',
        _ => '',
      };

  static Future<void> _copyAsTsv(
      BuildContext context, TimesheetWeek week) async {
    final buffer = StringBuffer();

    // Header line
    final dayHeaders = week.days
        .map((d) => '${_shortDay(d.weekday)} ${d.day} ${_shortMonth(d.month)}')
        .toList();
    buffer
        .writeln(['Code', 'Classification', ...dayHeaders, 'Total'].join('\t'));

    // Row lines
    for (final row in week.rows) {
      final cellStrings = row.cells.map(formatCell).toList();
      buffer.writeln([
        row.code,
        row.classification.label,
        ...cellStrings,
        row.total.toStringAsFixed(2),
      ].join('\t'));
    }

    // Totals line
    final dailyTotalStrings = week.dailyTotals.map(formatCell).toList();
    buffer.writeln([
      'Total',
      '',
      ...dailyTotalStrings,
      week.total.toStringAsFixed(2),
    ].join('\t'));

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const AppSnackBar.success(
            message: 'Week timesheet copied to clipboard (TSV)'),
      );
    }
  }
}

class _HeaderRow extends StatelessWidget {
  final List<DateTime> days;
  final DateTime today;

  const _HeaderRow({required this.days, required this.today});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Container(
      color: colors.card.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: _WeekGridCard._codeWidth,
            child: Text(
              'Code',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: _WeekGridCard._classWidth,
            child: Text(
              'Class',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (var i = 0; i < days.length; i++) ...[
            _DayHeaderCell(
              date: days[i],
              isToday: _isSameDay(days[i], today),
            ),
          ],
          SizedBox(
            width: _WeekGridCard._totalWidth,
            child: Text(
              'Total',
              textAlign: TextAlign.right,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayHeaderCell extends StatelessWidget {
  final DateTime date;
  final bool isToday;

  const _DayHeaderCell({required this.date, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final dayName = _WeekGridCard._shortDay(date.weekday);

    return Container(
      width: _WeekGridCard._dayWidth,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: isToday
            ? colors.accent.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: Radii.xsAll,
      ),
      child: Column(
        children: [
          Text(
            dayName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isToday ? colors.accent : colors.textSecondary,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          Text(
            '${date.day}',
            style: AppTypography.numeric(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? colors.accent : colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final TimesheetGridRow row;
  final List<DateTime> days;
  final DateTime today;

  const _DataRow({
    required this.row,
    required this.days,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final classColor = row.classification.colorOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.sm),
      child: Row(
        children: [
          // Code Column
          SizedBox(
            width: _WeekGridCard._codeWidth,
            child: row.code.isNotEmpty
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (row.needsAttention) ...[
                        Tooltip(
                          message: '${row.projectName ?? "Project"} · '
                              '${row.optionLabel ?? "Default timesheet code"}',
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: IconSizes.sm,
                            color: colors.warning,
                          ),
                        ),
                        const SizedBox(width: Spacing.xs),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sm,
                            vertical: Spacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: Radii.smAll,
                            border: Border.all(color: colors.divider),
                          ),
                          child: Text(
                            row.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.numeric(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.xs),
                      Tooltip(
                        message: 'Copy code',
                        child: InkWell(
                          onTap: () async {
                            await Clipboard.setData(
                                ClipboardData(text: row.code));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showAppSnackBar(
                                AppSnackBar.success(
                                    message:
                                        'Code "${row.code}" copied to clipboard'),
                              );
                            }
                          },
                          borderRadius: Radii.xsAll,
                          child: Padding(
                            padding: const EdgeInsets.all(Spacing.xxs),
                            child: Icon(
                              Icons.copy,
                              size: IconSizes.xs,
                              color: colors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      if (row.needsAttention) ...[
                        Tooltip(
                          message: '${row.projectName ?? "Project"} · '
                              '${row.optionLabel ?? "Default timesheet code"}',
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: IconSizes.sm,
                            color: colors.warning,
                          ),
                        ),
                        const SizedBox(width: Spacing.xs),
                      ],
                      Icon(
                        Icons.help_outline,
                        size: IconSizes.xs,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(width: Spacing.xs),
                      Expanded(
                        child: Text(
                          row.codeLabel,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // Classification Column
          SizedBox(
            width: _WeekGridCard._classWidth,
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: classColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  row.classification.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: classColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // 7 Day Cells
          for (var i = 0; i < days.length; i++) ...[
            _DayDataCell(
              value: row.cells[i],
              isToday: _HeaderRow._isSameDay(days[i], today),
            ),
          ],

          // Total Column
          SizedBox(
            width: _WeekGridCard._totalWidth,
            child: Text(
              row.total.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: AppTypography.numeric(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDataCell extends StatelessWidget {
  final double value;
  final bool isToday;

  const _DayDataCell({required this.value, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final text = formatCell(value);

    return Container(
      width: _WeekGridCard._dayWidth,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
      decoration: BoxDecoration(
        color: isToday
            ? colors.accent.withValues(alpha: 0.04)
            : Colors.transparent,
      ),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: AppTypography.numeric(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: value > 0 ? colors.textPrimary : colors.textTertiary,
        ),
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  final TimesheetWeek week;
  final DateTime today;

  const _TotalsRow({required this.week, required this.today});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Container(
      color: colors.card.withValues(alpha: 0.2),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: _WeekGridCard._codeWidth,
            child: Text(
              'Total',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: _WeekGridCard._classWidth),
          for (var i = 0; i < week.days.length; i++) ...[
            Container(
              width: _WeekGridCard._dayWidth,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
              decoration: BoxDecoration(
                color: _HeaderRow._isSameDay(week.days[i], today)
                    ? colors.accent.withValues(alpha: 0.08)
                    : Colors.transparent,
              ),
              child: Text(
                formatCell(week.dailyTotals[i]),
                textAlign: TextAlign.right,
                style: AppTypography.numeric(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: week.dailyTotals[i] > 0
                      ? colors.textPrimary
                      : colors.textTertiary,
                ),
              ),
            ),
          ],
          SizedBox(
            width: _WeekGridCard._totalWidth,
            child: Text(
              week.total.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: AppTypography.numeric(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TruncationNotice extends StatelessWidget {
  final int maxWeeks;
  final WorkPulseColors colors;

  const _TruncationNotice({required this.maxWeeks, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.mdAll,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: IconSizes.sm,
            color: colors.textSecondary,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              'Showing the first $maxWeeks weeks. Select a shorter date range '
              'to view individual weekly breakdowns.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
