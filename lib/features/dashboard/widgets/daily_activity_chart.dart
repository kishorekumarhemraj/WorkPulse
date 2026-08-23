import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/services/timer_service.dart';

class DailyActivityChart extends StatelessWidget {
  final List<DailyActivityItem> activities;
  final List<HourlyActivityItem> hourlyActivities;
  final bool isHourly;

  const DailyActivityChart({
    super.key,
    this.activities = const [],
    this.hourlyActivities = const [],
    this.isHourly = false,
  });

  String _formatHourLabel(int hour) {
    if (hour == 0) return '12a';
    if (hour == 12) return '12p';
    if (hour < 12) return '${hour}a';
    return '${hour - 12}p';
  }

  String _formatHourFullRange(int hour) {
    final start = DateTime(2026, 1, 1, hour);
    final end = DateTime(2026, 1, 1, (hour + 1) % 24);
    final startStr = DateFormat('h:mm a').format(start);
    final endStr = DateFormat('h:mm a').format(end);
    return '$startStr – $endStr';
  }

  @override
  Widget build(BuildContext context) {
    if (isHourly) {
      if (hourlyActivities.isEmpty) return const SizedBox.shrink();
      return _buildHourlyChart(context);
    } else {
      if (activities.isEmpty) return const SizedBox.shrink();
      return _buildDailyChart(context);
    }
  }

  Widget _buildHourlyChart(BuildContext context) {
    int maxSeconds = 3600; // Baseline to 1 hour
    for (final h in hourlyActivities) {
      final total = h.totalDuration.inSeconds;
      if (total > maxSeconds) {
        maxSeconds = total;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.getColors(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getColors(context).divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Today\'s Hourly Breakdown (24 Hours)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getColors(context).textPrimary,
                ),
              ),
              const Spacer(),
              // Legend
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.getColors(context).textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Idle',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.getColors(context).textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 24 Hour Bars
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: hourlyActivities.map((item) {
                final activeHeight =
                    (item.activeDuration.inSeconds / maxSeconds) * 95;
                final idleHeight =
                    (item.idleDuration.inSeconds / maxSeconds) * 95;
                final hasData = item.totalDuration.inSeconds > 0;
                final hourRangeStr = _formatHourFullRange(item.hour);
                final durationTooltip =
                    'Active: ${TimerService.formatDuration(item.activeDuration, includeSeconds: false)}\nIdle: ${TimerService.formatDuration(item.idleDuration, includeSeconds: false)}';
                final isMajorHour = item.hour % 3 == 0;

                return Expanded(
                  child: Tooltip(
                    message: '$hourRangeStr\n$durationTooltip',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (hasData)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.idleDuration.inSeconds > 0)
                                  Container(
                                    width: 12,
                                    height: idleHeight.clamp(2.0, 95.0),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accentOrange,
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(2)),
                                    ),
                                  ),
                                if (item.activeDuration.inSeconds > 0)
                                  Container(
                                    width: 12,
                                    height: activeHeight.clamp(4.0, 95.0),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentGreen,
                                      borderRadius: item.idleDuration.inSeconds > 0
                                          ? BorderRadius.zero
                                          : const BorderRadius.vertical(
                                              top: Radius.circular(2)),
                                    ),
                                  ),
                              ],
                            )
                          else
                            Container(
                              width: 10,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppTheme.getColors(context)
                                    .divider
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            _formatHourLabel(item.hour),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isMajorHour
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isMajorHour
                                  ? AppTheme.getColors(context).textPrimary
                                  : AppTheme.getColors(context).textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyChart(BuildContext context) {
    // Find max duration to scale bars
    int maxSeconds = 1;
    for (final a in activities) {
      final total = a.totalDuration.inSeconds;
      if (total > maxSeconds) {
        maxSeconds = total;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.getColors(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getColors(context).divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Daily Focus & Activity Trend',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getColors(context).textPrimary,
                ),
              ),
              const Spacer(),
              // Legend
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.getColors(context).textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Idle',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.getColors(context).textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart Row
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: activities.map((item) {
                final activeHeight =
                    (item.activeDuration.inSeconds / maxSeconds) * 95;
                final idleHeight =
                    (item.idleDuration.inSeconds / maxSeconds) * 95;
                final dayLabel = DateFormat.E().format(item.date);
                final dateLabel = DateFormat.d().format(item.date);
                final hasData = item.totalDuration.inSeconds > 0;
                final durationTooltip =
                    'Active: ${TimerService.formatDuration(item.activeDuration, includeSeconds: false)}\nIdle: ${TimerService.formatDuration(item.idleDuration, includeSeconds: false)}';

                return Expanded(
                  child: Tooltip(
                    message:
                        '${DateFormat.yMMMd().format(item.date)}\n$durationTooltip',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (hasData)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.idleDuration.inSeconds > 0)
                                  Container(
                                    width: 14,
                                    height: idleHeight.clamp(2.0, 95.0),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accentOrange,
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(3)),
                                    ),
                                  ),
                                if (item.activeDuration.inSeconds > 0)
                                  Container(
                                    width: 14,
                                    height: activeHeight.clamp(4.0, 95.0),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentGreen,
                                      borderRadius: item.idleDuration.inSeconds > 0
                                          ? BorderRadius.zero
                                          : const BorderRadius.vertical(
                                              top: Radius.circular(3)),
                                    ),
                                  ),
                              ],
                            )
                          else
                            Container(
                              width: 14,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppTheme.getColors(context).divider,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            dayLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getColors(context).textPrimary,
                            ),
                          ),
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.getColors(context).textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
