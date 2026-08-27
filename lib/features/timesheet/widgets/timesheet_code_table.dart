import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';
import 'package:workpulse/features/timesheet/widgets/timesheet_table.dart';

/// Headline table reporting time broken down by resolved timesheet code.
///
/// This matches the exact form the user has to fill into the organisation's
/// timesheet system.
class TimesheetCodeTable extends StatelessWidget {
  final List<TimesheetCodeRow> rows;
  final TimesheetHoursBasis basis;

  const TimesheetCodeTable({
    super.key,
    required this.rows,
    required this.basis,
  });

  static const double _codeColumnWidth = 140;
  static const double _sourcesColumnWidth = 220;
  static const double _numberColumnWidth = 92;
  static const double _shareColumnWidth = 132;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final showNone = rows.any((row) => row.split(basis).hasNone);

    final totals = rows.fold<ClassificationSplit>(
      ClassificationSplit.zero,
      (sum, row) => sum + row.split(basis),
    );

    final minWidth = _codeColumnWidth +
        _sourcesColumnWidth +
        _numberColumnWidth * (showNone ? 4 : 3) +
        _shareColumnWidth +
        Spacing.lg * 2;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.lg,
              Spacing.lg,
              Spacing.md,
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: IconSizes.lg, color: colors.textSecondary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('By timesheet code',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        'The hours to book in your timesheet system, resolved '
                        'per release where configured.',
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.max(constraints.maxWidth, minWidth);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CodeHeaderRow(showNone: showNone),
                      for (var i = 0; i < rows.length; i++)
                        _CodeDataRow(
                          row: rows[i],
                          basis: basis,
                          showNone: showNone,
                          isLast: i == rows.length - 1,
                        ),
                      _CodeTotalRow(
                        totals: totals,
                        showNone: showNone,
                      ),
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
}

class _CodeHeaderRow extends StatelessWidget {
  final bool showNone;

  const _CodeHeaderRow({required this.showNone});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = TimesheetPalette.of(context);
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: colors.textTertiary);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.divider),
          bottom: BorderSide(color: colors.divider),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: TimesheetCodeTable._codeColumnWidth,
            child: Text('CODE', style: style),
          ),
          SizedBox(
            width: TimesheetCodeTable._sourcesColumnWidth,
            child: Text('PROJECT · RELEASE', style: style),
          ),
          _CodeHeaderCell(label: 'CAPEX', color: palette.capex),
          _CodeHeaderCell(label: 'OPEX', color: palette.opex),
          if (showNone) _CodeHeaderCell(label: 'NONE', color: palette.none),
          _CodeHeaderCell(label: 'TOTAL', color: colors.textSecondary),
          SizedBox(
            width: TimesheetCodeTable._shareColumnWidth,
            child: Text('SPLIT', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _CodeHeaderCell extends StatelessWidget {
  final String label;
  final Color color;

  const _CodeHeaderCell({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TimesheetCodeTable._numberColumnWidth,
      child: Text(
        label,
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _CodeDataRow extends StatelessWidget {
  final TimesheetCodeRow row;
  final TimesheetHoursBasis basis;
  final bool showNone;
  final bool isLast;

  const _CodeDataRow({
    required this.row,
    required this.basis,
    required this.showNone,
    required this.isLast,
  });

  String _formatSources() {
    if (row.contributions.isEmpty) return '—';
    return row.contributions.map((c) {
      final opt = c.optionLabel?.trim();
      if (opt != null && opt.isNotEmpty) {
        return '${c.projectName} · $opt';
      }
      return c.projectName;
    }).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final palette = TimesheetPalette.of(context);
    final split = row.split(basis);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md - 2,
      ),
      decoration: BoxDecoration(
        border:
            isLast ? null : Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: TimesheetCodeTable._codeColumnWidth,
            child: _CodeDisplay(code: row.code),
          ),
          SizedBox(
            width: TimesheetCodeTable._sourcesColumnWidth,
            child: Text(
              _formatSources(),
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _CodeHoursCell(duration: split.capex, color: palette.capex),
          _CodeHoursCell(duration: split.opex, color: palette.opex),
          if (showNone)
            _CodeHoursCell(
              duration: split.none,
              color: palette.none,
            ),
          _CodeHoursCell(
            duration: split.total,
            color: colors.textPrimary,
            emphasis: true,
          ),
          SizedBox(
            width: TimesheetCodeTable._shareColumnWidth,
            child: SplitBar(split: split),
          ),
        ],
      ),
    );
  }
}

class _CodeDisplay extends StatelessWidget {
  final String code;

  const _CodeDisplay({required this.code});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final value = code.trim();

    if (value.isEmpty) {
      return Row(
        children: [
          Icon(
            Icons.help_outline,
            size: IconSizes.xs,
            color: colors.textTertiary,
          ),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              'No code',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
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
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.numeric(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CodeHoursCell extends StatelessWidget {
  final Duration duration;
  final Color color;
  final bool emphasis;

  const _CodeHoursCell({
    required this.duration,
    required this.color,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final isZero = duration <= Duration.zero;
    final colors = context.colors;

    return SizedBox(
      width: TimesheetCodeTable._numberColumnWidth,
      child: Text(
        formatTimesheetHours(duration),
        textAlign: TextAlign.right,
        style: AppTypography.numeric(
          fontSize: 13,
          fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
          color: isZero ? colors.textTertiary : color,
        ),
      ),
    );
  }
}

class _CodeTotalRow extends StatelessWidget {
  final ClassificationSplit totals;
  final bool showNone;

  const _CodeTotalRow({
    required this.totals,
    required this.showNone,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = TimesheetPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.borderStrong)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: TimesheetCodeTable._codeColumnWidth,
            child: Text(
              'Total',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: TimesheetCodeTable._sourcesColumnWidth),
          _CodeHoursCell(
            duration: totals.capex,
            color: palette.capex,
            emphasis: true,
          ),
          _CodeHoursCell(
            duration: totals.opex,
            color: palette.opex,
            emphasis: true,
          ),
          if (showNone)
            _CodeHoursCell(
              duration: totals.none,
              color: palette.none,
              emphasis: true,
            ),
          _CodeHoursCell(
            duration: totals.total,
            color: colors.textPrimary,
            emphasis: true,
          ),
          SizedBox(
            width: TimesheetCodeTable._shareColumnWidth,
            child: SplitBar(split: totals),
          ),
        ],
      ),
    );
  }
}
