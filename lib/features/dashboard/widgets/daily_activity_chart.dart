import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/services/timer_service.dart';

class DailyActivityChart extends StatelessWidget {
  final List<DailyActivityItem> activities;

  const DailyActivityChart({
    super.key,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const SizedBox.shrink();
    }

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
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Daily Focus & Activity Trend',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryDark,
                ),
              ),
              const Spacer(),
              // Legend
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: AppTheme.accentGreen, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  const Text('Active', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryDark)),
                  const SizedBox(width: 10),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: AppTheme.accentOrange, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  const Text('Idle', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryDark)),
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
                final activeHeight = (item.activeDuration.inSeconds / maxSeconds) * 95;
                final idleHeight = (item.idleDuration.inSeconds / maxSeconds) * 95;
                final dayLabel = DateFormat.E().format(item.date);
                final dateLabel = DateFormat.d().format(item.date);
                final hasData = item.totalDuration.inSeconds > 0;
                final durationTooltip = 'Active: ${TimerService.formatDuration(item.activeDuration, includeSeconds: false)}\nIdle: ${TimerService.formatDuration(item.idleDuration, includeSeconds: false)}';

                return Expanded(
                  child: Tooltip(
                    message: '${DateFormat.yMMMd().format(item.date)}\n$durationTooltip',
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
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                                    ),
                                  ),
                                if (item.activeDuration.inSeconds > 0)
                                  Container(
                                    width: 14,
                                    height: activeHeight.clamp(4.0, 95.0),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentGreen,
                                      borderRadius: item.idleDuration.inSeconds > 0 ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(3)),
                                    ),
                                  ),
                              ],
                            )
                          else
                            Container(
                              width: 14,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppTheme.dividerDark,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            dayLabel,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                          ),
                          Text(
                            dateLabel,
                            style: const TextStyle(fontSize: 9, color: AppTheme.textSecondaryDark),
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
