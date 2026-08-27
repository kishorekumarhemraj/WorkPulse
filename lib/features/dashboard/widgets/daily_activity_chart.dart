import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/services/timer_service.dart';

/// The activity timeline — stacked active/idle bars, hourly for a single day
/// and daily for longer ranges.
///
/// Adds a value axis, a "now" marker on the hourly view, and hover feedback,
/// so a bar's height can actually be read rather than only compared. Each
/// bar also carries its active time in HH:MM directly above it, so the
/// figure is readable without a mouse — the tooltip is for the detail
/// (idle, session count), not for the headline number.
class DailyActivityChart extends StatefulWidget {
  final List<DailyActivityItem> activities;
  final List<HourlyActivityItem> hourlyActivities;
  final bool isHourly;
  final String? title;
  final bool isToday;

  const DailyActivityChart({
    super.key,
    this.activities = const [],
    this.hourlyActivities = const [],
    this.isHourly = false,
    this.title,
    this.isToday = true,
  });

  @override
  State<DailyActivityChart> createState() => _DailyActivityChartState();
}

class _DailyActivityChartState extends State<DailyActivityChart> {
  int? _hoveredIndex;

  static const double _plotHeight = 150;

  /// The height reserved for a bar's value label.
  static const double _valueLabelHeight = 13;

  /// Below this column width an `HH:MM` label would collide with its
  /// neighbours, so the labels give way and the tooltip carries the value
  /// again. A month of daily bars in a narrow window is the case this
  /// protects.
  static const double _minWidthForValueLabel = 34;

  String _formatHourLabel(int hour) {
    if (hour == 0) return '12a';
    if (hour == 12) return '12p';
    if (hour < 12) return '${hour}a';
    return '${hour - 12}p';
  }

  String _formatHourFullRange(int hour) {
    final start = DateTime(2026, 1, 1, hour);
    final end = DateTime(2026, 1, 1, (hour + 1) % 24);
    return '${DateFormat('h:mm a').format(start)} – '
        '${DateFormat('h:mm a').format(end)}';
  }

  /// Rounds the axis maximum up to a whole number of hours so gridline labels
  /// read as clean values rather than arbitrary minute counts.
  int _axisMaxSeconds(int observedMax) {
    const hour = 3600;
    if (observedMax <= hour) return hour;
    return ((observedMax + hour - 1) ~/ hour) * hour;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHourly) {
      if (widget.hourlyActivities.isEmpty) return const SizedBox.shrink();
      final chartTitle = widget.title ??
          (widget.isToday ? "Today's Hourly Breakdown" : 'Hourly Breakdown');
      return _buildChart(
        context,
        title: chartTitle,
        icon: Icons.access_time,
        bars: [
          for (final h in widget.hourlyActivities)
            _BarData(
              label: _formatHourLabel(h.hour),
              tooltipTitle: _formatHourFullRange(h.hour),
              active: h.activeDuration,
              idle: h.idleDuration,
              sessionCount: h.sessionCount,
              isNow: widget.isToday && h.hour == DateTime.now().hour,
              showLabel: h.hour % 3 == 0,
            ),
        ],
      );
    }

    if (widget.activities.isEmpty) return const SizedBox.shrink();
    final dayFormat = DateFormat('E');
    final fullFormat = DateFormat('EEE, MMM d');
    final today = DateTime.now();
    // With many days on screen, labelling every bar becomes unreadable.
    final labelEvery = (widget.activities.length / 12).ceil().clamp(1, 7);

    return _buildChart(
      context,
      title: 'Daily Activity',
      icon: Icons.bar_chart,
      bars: [
        for (var i = 0; i < widget.activities.length; i++)
          () {
            final a = widget.activities[i];
            final date = a.date.toLocal();
            return _BarData(
              label: dayFormat.format(date),
              tooltipTitle: fullFormat.format(date),
              active: a.activeDuration,
              idle: a.idleDuration,
              sessionCount: a.sessionCount,
              isNow: date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day,
              showLabel: i % labelEvery == 0,
            );
          }(),
      ],
    );
  }

  Widget _buildChart(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_BarData> bars,
  }) {
    final colors = context.colors;
    final theme = Theme.of(context);

    var observedMax = 0;
    for (final bar in bars) {
      final total = bar.total.inSeconds;
      if (total > observedMax) observedMax = total;
    }
    final maxSeconds = _axisMaxSeconds(observedMax);

    return AppCard(
      padding: const EdgeInsets.all(Spacing.lg + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: IconSizes.md, color: colors.accent),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              _LegendSwatch(label: 'Active', color: colors.successFill),
              const SizedBox(width: Spacing.md),
              _LegendSwatch(label: 'Idle', color: colors.warningFill),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          SizedBox(
            height: _plotHeight + 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ValueAxis(maxSeconds: maxSeconds, height: _plotHeight),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columnWidth = bars.isEmpty
                          ? 0.0
                          : constraints.maxWidth / bars.length;
                      final showValues = columnWidth >= _minWidthForValueLabel;

                      return Stack(
                        children: [
                          // Gridlines sit behind the bars so heights can be
                          // read against them.
                          Positioned.fill(
                            bottom: 22,
                            child: _Gridlines(color: colors.divider),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var i = 0; i < bars.length; i++)
                                Expanded(
                                  child: _Bar(
                                    data: bars[i],
                                    maxSeconds: maxSeconds,
                                    plotHeight: _plotHeight,
                                    valueLabelHeight: _valueLabelHeight,
                                    showValue: showValues,
                                    isHovered: _hoveredIndex == i,
                                    onHover: (hovering) => setState(
                                      () => _hoveredIndex = hovering ? i : null,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarData {
  final String label;
  final String tooltipTitle;
  final Duration active;
  final Duration idle;
  final int sessionCount;
  final bool isNow;
  final bool showLabel;

  const _BarData({
    required this.label,
    required this.tooltipTitle,
    required this.active,
    required this.idle,
    required this.sessionCount,
    required this.isNow,
    required this.showLabel,
  });

  Duration get total => active + idle;
}

class _Bar extends StatelessWidget {
  final _BarData data;
  final int maxSeconds;
  final double plotHeight;
  final double valueLabelHeight;
  final bool showValue;
  final bool isHovered;
  final ValueChanged<bool> onHover;

  const _Bar({
    required this.data,
    required this.maxSeconds,
    required this.plotHeight,
    required this.valueLabelHeight,
    required this.showValue,
    required this.isHovered,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final activeHeight =
        (data.active.inSeconds / maxSeconds).clamp(0.0, 1.0) * plotHeight;
    final idleHeight =
        (data.idle.inSeconds / maxSeconds).clamp(0.0, 1.0) * plotHeight;
    final isEmpty = data.total == Duration.zero;

    final tooltip = StringBuffer(data.tooltipTitle)
      ..write('\n')
      ..write(
        isEmpty
            ? 'No activity'
            : 'Active ${TimerService.formatDuration(data.active, includeSeconds: false)}',
      );
    if (data.idle > Duration.zero) {
      tooltip.write(
        '\nIdle ${TimerService.formatDuration(data.idle, includeSeconds: false)}',
      );
    }
    if (data.sessionCount > 0) {
      tooltip.write(
        '\n${data.sessionCount} session${data.sessionCount == 1 ? '' : 's'}',
      );
    }

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Tooltip(
        message: tooltip.toString(),
        waitDuration: const Duration(milliseconds: 200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: plotHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (idleHeight > 0)
                            _Segment(
                              height: idleHeight,
                              color: colors.warningFill,
                              isHovered: isHovered,
                              isTop: true,
                            ),
                          if (activeHeight > 0)
                            _Segment(
                              height: activeHeight,
                              color: colors.successFill,
                              isHovered: isHovered,
                              isTop: idleHeight <= 0,
                            ),
                          if (isEmpty)
                            // A visible baseline keeps empty slots readable
                            // as "nothing tracked" rather than as a gap in
                            // the chart.
                            Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: isHovered
                                    ? colors.borderStrong
                                    : colors.divider,
                                borderRadius: Radii.xsAll,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // The bar's own active time, sitting on top of it. Riding
                    // the bar rather than pinned to the top of the plot keeps
                    // the number attached to the thing it measures; the
                    // clamp is what stops the tallest bar pushing its own
                    // label out of the chart.
                    if (showValue && data.active > Duration.zero)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: math.min(
                          activeHeight + idleHeight + 3,
                          plotHeight - valueLabelHeight,
                        ),
                        child: Text(
                          TimerService.formatDuration(
                            data.active,
                            includeSeconds: false,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: AppTypography.numeric(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isHovered
                                ? colors.textPrimary
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.sm - 2),
              SizedBox(
                height: 14,
                child: data.showLabel || isHovered
                    ? Text(
                        data.label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 0,
                          fontWeight:
                              data.isNow ? FontWeight.w700 : FontWeight.w500,
                          color: data.isNow
                              ? colors.accent
                              : (isHovered
                                  ? colors.textPrimary
                                  : colors.textTertiary),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final double height;
  final Color color;
  final bool isHovered;
  final bool isTop;

  const _Segment({
    required this.height,
    required this.color,
    required this.isHovered,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: height),
      duration: Motion.duration(context, Motion.slow),
      curve: Motion.curve,
      builder: (context, value, _) => AnimatedContainer(
        duration: Motion.duration(context, Motion.fast),
        width: double.infinity,
        height: value,
        decoration: BoxDecoration(
          color: isHovered ? color : color.withValues(alpha: 0.78),
          borderRadius: isTop
              ? const BorderRadius.vertical(top: Radius.circular(3))
              : BorderRadius.zero,
        ),
      ),
    );
  }
}

/// The vertical scale, labelled at 0%, 50% and 100% of the axis maximum.
class _ValueAxis extends StatelessWidget {
  final int maxSeconds;
  final double height;

  const _ValueAxis({required this.maxSeconds, required this.height});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    String label(int seconds) => TimerService.formatDuration(
          Duration(seconds: seconds),
          includeSeconds: false,
        );

    Widget tick(String text) => Text(
          text,
          textAlign: TextAlign.right,
          style: AppTypography.numeric(
            fontSize: 11,
            color: colors.textTertiary,
          ),
        );

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          tick(label(maxSeconds)),
          tick(label(maxSeconds ~/ 2)),
          tick('0'),
        ],
      ),
    );
  }
}

class _Gridlines extends StatelessWidget {
  final Color color;

  const _Gridlines({required this.color});

  @override
  Widget build(BuildContext context) {
    Widget line() => Container(height: 1, color: color.withValues(alpha: 0.55));
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [line(), line(), line()],
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendSwatch({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: Radii.xsAll),
        ),
        const SizedBox(width: Spacing.xs + 1),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
