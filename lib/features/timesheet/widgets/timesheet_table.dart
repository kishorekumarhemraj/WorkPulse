import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';

/// Decimal hours, the unit every timesheet system actually accepts.
///
/// `2.75` rather than `2h 45m`: the point of this screen is that the numbers
/// on it can be typed straight into whatever form the user has to fill in.
String formatTimesheetHours(Duration duration) {
  if (duration <= Duration.zero) return '0.00';
  return (duration.inSeconds / 3600).toStringAsFixed(2);
}

/// The colours the CAPEX/OPEX/unclassified columns carry throughout the
/// screen. Every use pairs one with its column heading or a legend label —
/// the split is never communicated by colour alone.
class TimesheetPalette {
  final Color capex;
  final Color opex;
  final Color unclassified;

  const TimesheetPalette({
    required this.capex,
    required this.opex,
    required this.unclassified,
  });

  factory TimesheetPalette.of(BuildContext context) {
    final colors = context.colors;
    return TimesheetPalette(
      capex: colors.accent,
      opex: colors.warning,
      unclassified: colors.textTertiary,
    );
  }
}

/// One CAPEX/OPEX table: a heading, a header row, then a row per project or
/// per attribute value, closed by a totals row.
class TimesheetTable extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final List<TimesheetRow> rows;
  final TimesheetHoursBasis basis;

  /// The label for the first column — 'Project', or the attribute's name.
  final String nameColumnLabel;

  const TimesheetTable({
    super.key,
    required this.title,
    required this.icon,
    required this.rows,
    required this.basis,
    required this.nameColumnLabel,
    this.subtitle,
  });

  static const double _nameColumnWidth = 220;
  static const double _numberColumnWidth = 92;
  static const double _shareColumnWidth = 132;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    // The column only earns its width when there is unclassified time to
    // report; most workspaces will never see it.
    final showUnclassified =
        rows.any((row) => row.split(basis).hasUnclassified);

    final totals = rows.fold<CapexOpexSplit>(
      CapexOpexSplit.zero,
      (sum, row) => sum + row.split(basis),
    );

    final minWidth = _nameColumnWidth +
        _numberColumnWidth * (showUnclassified ? 4 : 3) +
        _shareColumnWidth +
        Spacing.lg * 2;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: Radii.xlAll,
        border: Border.all(color: colors.divider),
      ),
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
                Icon(icon, size: IconSizes.lg, color: colors.textSecondary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null) ...[
                        const SizedBox(height: Spacing.xxs),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // A table has a floor below which its columns stop being readable.
          // Rather than let it overflow on a narrow window, it scrolls
          // sideways inside its own card and the page never does.
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
                      _HeaderRow(
                        nameColumnLabel: nameColumnLabel,
                        showUnclassified: showUnclassified,
                      ),
                      for (final row in rows)
                        _DataRow(
                          row: row,
                          basis: basis,
                          showUnclassified: showUnclassified,
                        ),
                      _TotalRow(
                        totals: totals,
                        showUnclassified: showUnclassified,
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

class _HeaderRow extends StatelessWidget {
  final String nameColumnLabel;
  final bool showUnclassified;

  const _HeaderRow({
    required this.nameColumnLabel,
    required this.showUnclassified,
  });

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
        color: colors.surfaceSunken,
        border: Border(
          top: BorderSide(color: colors.divider),
          bottom: BorderSide(color: colors.divider),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: TimesheetTable._nameColumnWidth,
            child: Text(nameColumnLabel.toUpperCase(), style: style),
          ),
          _HeaderCell(label: 'CAPEX', color: palette.capex),
          _HeaderCell(label: 'OPEX', color: palette.opex),
          if (showUnclassified)
            _HeaderCell(
              label: 'UNCLASSIFIED',
              color: palette.unclassified,
            ),
          _HeaderCell(label: 'TOTAL', color: colors.textSecondary),
          SizedBox(
            width: TimesheetTable._shareColumnWidth,
            child: Text('SPLIT', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final Color color;

  const _HeaderCell({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TimesheetTable._numberColumnWidth,
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

class _DataRow extends StatelessWidget {
  final TimesheetRow row;
  final TimesheetHoursBasis basis;
  final bool showUnclassified;

  const _DataRow({
    required this.row,
    required this.basis,
    required this.showUnclassified,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final palette = TimesheetPalette.of(context);
    final split = row.split(basis);
    final swatch =
        row.colorHex == null ? null : ColorUtils.parseHex(row.colorHex);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md - 2,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: TimesheetTable._nameColumnWidth,
            child: Row(
              children: [
                if (swatch != null) ...[
                  Container(
                    width: Spacing.sm,
                    height: Spacing.sm,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                ],
                Expanded(
                  child: Text(
                    row.label,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _HoursCell(duration: split.capex, color: palette.capex),
          _HoursCell(duration: split.opex, color: palette.opex),
          if (showUnclassified)
            _HoursCell(
              duration: split.unclassified,
              color: palette.unclassified,
            ),
          _HoursCell(
            duration: split.total,
            color: colors.textPrimary,
            emphasis: true,
          ),
          SizedBox(
            width: TimesheetTable._shareColumnWidth,
            child: SplitBar(split: split),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final CapexOpexSplit totals;
  final bool showUnclassified;

  const _TotalRow({required this.totals, required this.showUnclassified});

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
        color: colors.surfaceSunken,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(Radii.xl),
          bottomRight: Radius.circular(Radii.xl),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: TimesheetTable._nameColumnWidth,
            child: Text(
              'Total',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
          ),
          _HoursCell(
            duration: totals.capex,
            color: palette.capex,
            emphasis: true,
          ),
          _HoursCell(
            duration: totals.opex,
            color: palette.opex,
            emphasis: true,
          ),
          if (showUnclassified)
            _HoursCell(
              duration: totals.unclassified,
              color: palette.unclassified,
              emphasis: true,
            ),
          _HoursCell(
            duration: totals.total,
            color: colors.textPrimary,
            emphasis: true,
          ),
          SizedBox(
            width: TimesheetTable._shareColumnWidth,
            child: SplitBar(split: totals),
          ),
        ],
      ),
    );
  }
}

class _HoursCell extends StatelessWidget {
  final Duration duration;
  final Color color;
  final bool emphasis;

  const _HoursCell({
    required this.duration,
    required this.color,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final isZero = duration <= Duration.zero;
    final colors = context.colors;

    return SizedBox(
      width: TimesheetTable._numberColumnWidth,
      child: Text(
        formatTimesheetHours(duration),
        textAlign: TextAlign.right,
        style: AppTypography.numeric(
          fontSize: 13,
          fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
          // A zero reads as noise beside the figures that matter, so it is
          // dimmed rather than dropped — the cell still lines up.
          color: isZero ? colors.textTertiary : color,
        ),
      ),
    );
  }
}

/// A stacked bar showing how a row divides between CAPEX and OPEX.
///
/// Labelled with the CAPEX percentage beside it, so the proportion is
/// readable without depending on the two hues being distinguishable.
class SplitBar extends StatelessWidget {
  final CapexOpexSplit split;

  const SplitBar({super.key, required this.split});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = TimesheetPalette.of(context);
    final theme = Theme.of(context);
    final total = split.total.inSeconds;

    if (total <= 0) {
      return Text(
        '—',
        textAlign: TextAlign.right,
        style: theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: Radii.pillAll,
            child: SizedBox(
              height: Spacing.sm - 2,
              child: Row(
                children: [
                  if (split.capex.inSeconds > 0)
                    Expanded(
                      flex: split.capex.inSeconds,
                      child: ColoredBox(color: palette.capex),
                    ),
                  if (split.opex.inSeconds > 0)
                    Expanded(
                      flex: split.opex.inSeconds,
                      child: ColoredBox(color: palette.opex),
                    ),
                  if (split.unclassified.inSeconds > 0)
                    Expanded(
                      flex: split.unclassified.inSeconds,
                      child: ColoredBox(color: palette.unclassified),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        SizedBox(
          width: 44,
          child: Text(
            '${split.capexShare.round()}%',
            textAlign: TextAlign.right,
            style: AppTypography.numeric(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
