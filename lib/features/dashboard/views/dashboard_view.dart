import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/dashboard/providers/dashboard_provider.dart';
import 'package:workpulse/features/dashboard/widgets/breakdown_card.dart';
import 'package:workpulse/features/dashboard/widgets/daily_activity_chart.dart';
import 'package:workpulse/features/dashboard/widgets/metric_card.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  String _formatRangeSubtitle(DateRange range) {
    final startStr = DateFormat.yMMMd().format(range.start.toLocal());
    final endStr = DateFormat.yMMMd().format(range.end.toLocal());

    if (startStr == endStr) {
      return startStr;
    }
    return '$startStr – $endStr';
  }

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final currentCustom = ref.read(customDateRangeProvider);
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: currentCustom ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.surfaceDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(customDateRangeProvider.notifier).setCustomRange(picked);
      ref
          .read(selectedTimeRangeProvider.notifier)
          .setRange(DashboardTimeRange.custom);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(selectedTimeRangeProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return Scaffold(
      backgroundColor: AppTheme.getColors(context).background,
      body: dashboardAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, stack) => Center(
          child: Text('Error loading dashboard: $err',
              style: TextStyle(color: AppTheme.accentRed)),
        ),
        data: (data) {
          final summary = data.summary;
          final totalTrackedStr = TimerService.formatDuration(
              summary.totalTrackedDuration,
              includeSeconds: false);
          final netActiveStr = TimerService.formatDuration(
              summary.totalActiveDuration,
              includeSeconds: false);
          final idleStr = TimerService.formatDuration(summary.totalIdleDuration,
              includeSeconds: false);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with Range Filters
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard & Insights',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getColors(context).textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatRangeSubtitle(data.range),
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getColors(context).textSecondary),
                        ),
                      ],
                    ),

                    // Time Range Selector Filter Pills
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.getColors(context).surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.getColors(context).divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: DashboardTimeRange.values.map((r) {
                          final isSelected = selectedRange == r;
                          return Material(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            child: InkWell(
                              onTap: () {
                                if (r == DashboardTimeRange.custom) {
                                  _pickCustomRange(context, ref);
                                } else {
                                  ref
                                      .read(selectedTimeRangeProvider.notifier)
                                      .setRange(r);
                                }
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                child: Text(
                                  r.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.getColors(context)
                                            .textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Refresh Button
                    IconButton(
                      onPressed: () => ref.invalidate(dashboardDataProvider),
                      icon: Icon(Icons.refresh,
                          size: 18,
                          color: AppTheme.getColors(context).textSecondary),
                      tooltip: 'Refresh analytics',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Top KPI Summary Metrics Row
                Row(
                  children: [
                    MetricCard(
                      title: 'Total Tracked',
                      value: totalTrackedStr,
                      subtitle: '${summary.sessionCount} sessions logged',
                      icon: Icons.timer_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 14),
                    MetricCard(
                      title: 'Net Focus Time',
                      value: netActiveStr,
                      subtitle: summary.totalTrackedDuration.inSeconds > 0
                          ? '${((summary.totalActiveDuration.inSeconds / summary.totalTrackedDuration.inSeconds) * 100).toStringAsFixed(0)}% efficiency'
                          : '100% efficiency',
                      icon: Icons.bolt,
                      color: AppTheme.accentGreen,
                    ),
                    const SizedBox(width: 14),
                    MetricCard(
                      title: 'Idle Time',
                      value: idleStr,
                      subtitle: 'Excluded inactivity',
                      icon: Icons.nightlight_round,
                      color: AppTheme.accentOrange,
                    ),
                    const SizedBox(width: 14),
                    MetricCard(
                      title: 'Active Tasks',
                      value: '${summary.taskCount}',
                      subtitle: '${summary.sessionCount} total sessions',
                      icon: Icons.task_alt,
                      color: AppTheme.accentPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Daily Activity Timeline Chart
                if (data.dailyActivity.isNotEmpty) ...[
                  DailyActivityChart(activities: data.dailyActivity),
                  const SizedBox(height: 24),
                ],

                // 2-Column Breakdown Layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column
                    Expanded(
                      child: Column(
                        children: [
                          BreakdownCard(
                            title: 'Time by Project',
                            icon: Icons.folder_outlined,
                            items: data.projectBreakdown,
                            emptyMessage:
                                'No project activity recorded in this period',
                          ),
                          const SizedBox(height: 20),
                          BreakdownCard(
                            title: 'Time by Category',
                            icon: Icons.category_outlined,
                            items: data.categoryBreakdown,
                            emptyMessage:
                                'No category activity recorded in this period',
                          ),
                          if (data.tagBreakdown.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            BreakdownCard(
                              title: 'Time by Tags',
                              icon: Icons.label_outline,
                              items: data.tagBreakdown,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Right Column
                    Expanded(
                      child: Column(
                        children: [
                          BreakdownCard(
                            title: 'Top Tasks Tracked',
                            icon: Icons.checklist,
                            items: data.workItemBreakdown,
                            emptyMessage:
                                'No task activity recorded in this period',
                          ),
                          if (data.personBreakdown.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            BreakdownCard(
                              title: 'Time by People',
                              icon: Icons.person_outline,
                              items: data.personBreakdown,
                            ),
                          ],
                          // Configurable Attributes Breakdown (e.g. Billable vs Non-Billable)
                          ...data.attributeBreakdowns.map((group) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: BreakdownCard(
                                title: group.definition.name,
                                icon: Icons.tune,
                                items: group.items,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
