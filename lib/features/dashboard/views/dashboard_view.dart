import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/core/widgets/page_header.dart';
import 'package:workpulse/core/widgets/segmented_control.dart';
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
    if (startStr == endStr) return startStr;
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
    final colors = context.colors;
    final selectedRange = ref.watch(selectedTimeRangeProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: dashboardAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => ErrorState(
          title: 'Could not load the dashboard',
          error: err,
          onRetry: () => ref.invalidate(dashboardDataProvider),
        ),
        data: (data) {
          final summary = data.summary;
          final isToday = selectedRange == DashboardTimeRange.today ||
              (data.hourlyActivity.isNotEmpty &&
                  data.range.duration <= const Duration(days: 1));

          final efficiency = summary.totalTrackedDuration.inSeconds > 0
              ? (summary.totalActiveDuration.inSeconds /
                      summary.totalTrackedDuration.inSeconds) *
                  100
              : 100.0;

          return PageScaffold(
            scrollable: true,
            title: 'Dashboard',
            subtitle: _formatRangeSubtitle(data.range),
            actions: [
              AppSegmentedControl<DashboardTimeRange>(
                selected: selectedRange,
                onChanged: (range) {
                  if (range == DashboardTimeRange.custom) {
                    _pickCustomRange(context, ref);
                  } else {
                    ref
                        .read(selectedTimeRangeProvider.notifier)
                        .setRange(range);
                  }
                },
                options: [
                  for (final range in DashboardTimeRange.values)
                    SegmentOption(value: range, label: range.label),
                ],
              ),
              IconButton(
                onPressed: () => ref.invalidate(dashboardDataProvider),
                icon: const Icon(Icons.refresh, size: IconSizes.lg),
                tooltip: 'Refresh analytics',
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricGrid(
                  cards: [
                    MetricCard(
                      title: 'Total Tracked',
                      value: TimerService.formatDuration(
                        summary.totalTrackedDuration,
                        includeSeconds: false,
                      ),
                      subtitle: '${summary.sessionCount} sessions logged',
                      icon: Icons.timer_outlined,
                      color: colors.accent,
                    ),
                    MetricCard(
                      title: 'Net Focus Time',
                      value: TimerService.formatDuration(
                        summary.totalActiveDuration,
                        includeSeconds: false,
                      ),
                      subtitle: '${efficiency.toStringAsFixed(0)}% efficiency',
                      icon: Icons.bolt,
                      color: colors.success,
                    ),
                    MetricCard(
                      title: 'Idle Time',
                      value: TimerService.formatDuration(
                        summary.totalIdleDuration,
                        includeSeconds: false,
                      ),
                      subtitle: 'Excluded inactivity',
                      icon: Icons.nightlight_round,
                      color: colors.warning,
                    ),
                    MetricCard(
                      title: 'Active Tasks',
                      value: '${summary.taskCount}',
                      subtitle: '${summary.sessionCount} total sessions',
                      icon: Icons.task_alt,
                      color: colors.info,
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.xxl),
                if (isToday
                    ? data.hourlyActivity.isNotEmpty
                    : data.dailyActivity.isNotEmpty) ...[
                  DailyActivityChart(
                    activities: data.dailyActivity,
                    hourlyActivities: data.hourlyActivity,
                    isHourly: isToday,
                  ),
                  const SizedBox(height: Spacing.xxl),
                ],
                _BreakdownColumns(data: data),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The KPI strip.
///
/// Previously four Expanded cards in a fixed Row, which overflowed as soon as
/// the window narrowed. Now it reflows 4 -> 2 -> 1 columns.
class _MetricGrid extends StatelessWidget {
  final List<Widget> cards;

  const _MetricGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= Breakpoints.medium
            ? 4
            : constraints.maxWidth >= Breakpoints.compact
                ? 2
                : 1;

        const gap = Spacing.lg;
        final cardWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

/// The "time by X" panels, in two columns on wide windows and one when narrow.
class _BreakdownColumns extends StatelessWidget {
  final DashboardData data;

  const _BreakdownColumns({required this.data});

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[
      BreakdownCard(
        title: 'Time by Project',
        icon: Icons.folder_outlined,
        items: data.projectBreakdown,
        emptyMessage: 'No project activity recorded in this period',
      ),
      BreakdownCard(
        title: 'Time by Category',
        icon: Icons.category_outlined,
        items: data.categoryBreakdown,
        emptyMessage: 'No category activity recorded in this period',
      ),
      if (data.tagBreakdown.isNotEmpty)
        BreakdownCard(
          title: 'Time by Tags',
          icon: Icons.label_outline,
          items: data.tagBreakdown,
        ),
    ];

    final right = <Widget>[
      BreakdownCard(
        title: 'Top Tasks Tracked',
        icon: Icons.checklist,
        items: data.workItemBreakdown,
        emptyMessage: 'No task activity recorded in this period',
      ),
      if (data.personBreakdown.isNotEmpty)
        BreakdownCard(
          title: 'Time by People',
          icon: Icons.person_outline,
          items: data.personBreakdown,
        ),
      // Configurable attribute breakdowns, e.g. Billable vs Non-Billable.
      for (final group in data.attributeBreakdowns)
        BreakdownCard(
          title: group.definition.name,
          icon: Icons.tune,
          items: group.items,
        ),
    ];

    Widget column(List<Widget> cards) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: Spacing.xl),
              cards[i],
            ],
          ],
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < Breakpoints.compact) {
          return column([...left, ...right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: column(left)),
            const SizedBox(width: Spacing.xl),
            Expanded(child: column(right)),
          ],
        );
      },
    );
  }
}
