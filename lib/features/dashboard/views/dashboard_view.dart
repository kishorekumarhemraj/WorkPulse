import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/date_stepper.dart';
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
import 'package:workpulse/features/reports/pdf_report_export.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  String _formatSubtitle(
    DashboardTimeRange range,
    DateTime selectedDate,
    DateRange dataRange,
  ) {
    final now = DateTime.now();
    switch (range) {
      case DashboardTimeRange.today:
        return 'Today · ${DateFormat.yMMMMEEEEd().format(selectedDate)}';
      case DashboardTimeRange.thisWeek:
        final startStr = DateFormat.yMMMd().format(dataRange.start.toLocal());
        final endStr = DateFormat.yMMMd().format(dataRange.end.toLocal());
        return 'This Week · $startStr – $endStr';
      case DashboardTimeRange.thisMonth:
        final monthStr = DateFormat.yMMMM().format(dataRange.start.toLocal());
        return 'This Month · $monthStr';
      case DashboardTimeRange.custom:
        final isToday = selectedDate.year == now.year &&
            selectedDate.month == now.month &&
            selectedDate.day == now.day;
        if (isToday) {
          return 'Today · ${DateFormat.yMMMMEEEEd().format(selectedDate)}';
        }
        return DateFormat.yMMMMEEEEd().format(selectedDate);
    }
  }

  String _formatDateButtonLabel(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final isTomorrow = date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;

    final formatted = DateFormat.yMMMd().format(date);
    if (isToday) return 'Today, $formatted';
    if (isYesterday) return 'Yesterday, $formatted';
    if (isTomorrow) return 'Tomorrow, $formatted';
    return '${DateFormat.E().format(date)}, $formatted';
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final currentDate = ref.read(dashboardDateProvider);
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      ref.read(dashboardDateProvider.notifier).setDate(picked);
      final isToday = picked.year == now.year &&
          picked.month == now.month &&
          picked.day == now.day;
      ref.read(selectedTimeRangeProvider.notifier).setRange(
            isToday ? DashboardTimeRange.today : DashboardTimeRange.custom,
          );
    }
  }

  Future<void> _exportPdf(
    BuildContext context,
    WidgetRef ref,
    DateRange range,
  ) {
    return PdfReportExport.run(
      context,
      ref,
      range: range,
      fileNamePrefix: 'WorkPulse_Daily_Report',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selectedRange = ref.watch(selectedTimeRangeProvider);
    final selectedDate = ref.watch(dashboardDateProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);

    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

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
          final isSingleDay = selectedRange == DashboardTimeRange.today ||
              selectedRange == DashboardTimeRange.custom ||
              data.range.duration <= const Duration(days: 1);

          final efficiency = summary.totalTrackedDuration.inSeconds > 0
              ? (summary.totalActiveDuration.inSeconds /
                      summary.totalTrackedDuration.inSeconds) *
                  100
              : 100.0;

          return PageScaffold(
            scrollable: true,
            title: 'Dashboard',
            subtitle: _formatSubtitle(selectedRange, selectedDate, data.range),
            actions: [
              // Time Range Segmented Control (Today, This Week, This Month, Date)
              AppSegmentedControl<DashboardTimeRange>(
                selected: selectedRange,
                onChanged: (range) {
                  ref.read(selectedTimeRangeProvider.notifier).setRange(range);
                  if (range == DashboardTimeRange.today) {
                    ref.read(dashboardDateProvider.notifier).goToToday();
                  } else if (range == DashboardTimeRange.custom) {
                    _pickDate(context, ref);
                  }
                },
                options: const [
                  SegmentOption(
                      value: DashboardTimeRange.today, label: 'Today'),
                  SegmentOption(
                      value: DashboardTimeRange.thisWeek, label: 'This Week'),
                  SegmentOption(
                      value: DashboardTimeRange.thisMonth, label: 'This Month'),
                  SegmentOption(
                      value: DashboardTimeRange.custom, label: 'Date'),
                ],
              ),
              // Date Navigation Bar (Previous day, Current Date, Next day)
              AppDateStepper(
                label: _formatDateButtonLabel(selectedDate),
                onPrevious: () {
                  ref.read(dashboardDateProvider.notifier).previousDay();
                  final newDate = ref.read(dashboardDateProvider);
                  final isNewToday = newDate.year == now.year &&
                      newDate.month == now.month &&
                      newDate.day == now.day;
                  ref.read(selectedTimeRangeProvider.notifier).setRange(
                        isNewToday
                            ? DashboardTimeRange.today
                            : DashboardTimeRange.custom,
                      );
                },
                onNext: () {
                  ref.read(dashboardDateProvider.notifier).nextDay();
                  final newDate = ref.read(dashboardDateProvider);
                  final isNewToday = newDate.year == now.year &&
                      newDate.month == now.month &&
                      newDate.day == now.day;
                  ref.read(selectedTimeRangeProvider.notifier).setRange(
                        isNewToday
                            ? DashboardTimeRange.today
                            : DashboardTimeRange.custom,
                      );
                },
                onPickDate: () => _pickDate(context, ref),
              ),
              Tooltip(
                message: 'Export colorful daily report as PDF',
                child: ElevatedButton.icon(
                  onPressed: () => _exportPdf(context, ref, data.range),
                  icon: const Icon(
                    Icons.picture_as_pdf_outlined,
                    size: IconSizes.sm,
                  ),
                  label: const Text('Export PDF'),
                ),
              ),
              IconButton(
                onPressed: () => ref.invalidate(dashboardDataProvider),
                icon: const Icon(Icons.refresh, size: IconSizes.md),
                tooltip: 'Refresh analytics',
                style: IconButton.styleFrom(
                  minimumSize:
                      const Size(ControlSizes.standard, ControlSizes.standard),
                  maximumSize:
                      const Size(ControlSizes.standard, ControlSizes.standard),
                  padding: EdgeInsets.zero,
                  shape:
                      const RoundedRectangleBorder(borderRadius: Radii.mdAll),
                ),
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
                if (isSingleDay
                    ? data.hourlyActivity.isNotEmpty
                    : data.dailyActivity.isNotEmpty) ...[
                  DailyActivityChart(
                    activities: data.dailyActivity,
                    hourlyActivities: data.hourlyActivity,
                    isHourly: isSingleDay,
                    isToday: isSingleDay && isToday,
                    title: isSingleDay
                        ? (isToday
                            ? "Today's Hourly Breakdown"
                            : 'Hourly Breakdown')
                        : 'Daily Activity',
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
