import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/widgets/date_stepper.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/core/widgets/page_header.dart';
import 'package:workpulse/core/widgets/segmented_control.dart';
import 'package:workpulse/core/widgets/skeleton_loader.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/reports/views/export_dialog.dart';
import 'package:workpulse/features/reports/views/session_edit_dialog.dart';
import 'package:workpulse/features/reports/widgets/session_day_group.dart';

class SessionHistoryView extends ConsumerWidget {
  const SessionHistoryView({super.key});

  String _formatSubtitle(
    DashboardTimeRange range,
    DateTime selectedDate,
  ) {
    final now = DateTime.now();
    switch (range) {
      case DashboardTimeRange.today:
        return 'Today · ${DateFormat.yMMMMEEEEd().format(selectedDate)}';
      case DashboardTimeRange.thisWeek:
        final dateRange = DashboardTimeRange.thisWeek.toDateRange();
        final startStr = DateFormat.yMMMd().format(dateRange.start.toLocal());
        final endStr = DateFormat.yMMMd().format(dateRange.end.toLocal());
        return 'This Week · $startStr – $endStr';
      case DashboardTimeRange.thisMonth:
        final dateRange = DashboardTimeRange.thisMonth.toDateRange();
        final monthStr = DateFormat.yMMMM().format(dateRange.start.toLocal());
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
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
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
    final currentDate = ref.read(reportsDateProvider);
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      ref.read(reportsDateProvider.notifier).setDate(picked);
      final isToday = picked.year == now.year &&
          picked.month == now.month &&
          picked.day == now.day;
      ref.read(reportsTimeRangeProvider.notifier).setRange(
            isToday ? DashboardTimeRange.today : DashboardTimeRange.custom,
          );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
    String taskName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Delete Session',
        icon: Icons.delete_outline,
        iconColor: context.colors.danger,
        width: DialogWidth.small,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.dangerFill,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
        child: Text(
          'Are you sure you want to delete this session for "$taskName"? '
          'This action cannot be undone.',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
      ),
    );

    if (confirmed == true) {
      await ref.read(sessionEditorControllerProvider).deleteSession(sessionId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selectedRange = ref.watch(reportsTimeRangeProvider);
    final selectedDate = ref.watch(reportsDateProvider);
    final sessionsAsync = ref.watch(sessionHistoryProvider);

    final now = DateTime.now();

    return Scaffold(
      backgroundColor: colors.background,
      body: PageScaffold(
        title: 'Time Log',
        subtitle: _formatSubtitle(selectedRange, selectedDate),
        actions: [
          // Time Range Segmented Control (Today, This Week, This Month, Date)
          AppSegmentedControl<DashboardTimeRange>(
            selected: selectedRange,
            onChanged: (range) {
              ref.read(reportsTimeRangeProvider.notifier).setRange(range);
              if (range == DashboardTimeRange.today) {
                ref.read(reportsDateProvider.notifier).goToToday();
              } else if (range == DashboardTimeRange.custom) {
                _pickDate(context, ref);
              }
            },
            options: const [
              SegmentOption(value: DashboardTimeRange.today, label: 'Today'),
              SegmentOption(
                  value: DashboardTimeRange.thisWeek, label: 'This Week'),
              SegmentOption(
                  value: DashboardTimeRange.thisMonth, label: 'This Month'),
              SegmentOption(value: DashboardTimeRange.custom, label: 'Date'),
            ],
          ),
          // Date Navigation Bar (Previous day, Current Date, Next day)
          AppDateStepper(
            label: _formatDateButtonLabel(selectedDate),
            onPrevious: () {
              ref.read(reportsDateProvider.notifier).previousDay();
              final newDate = ref.read(reportsDateProvider);
              final isNewToday = newDate.year == now.year &&
                  newDate.month == now.month &&
                  newDate.day == now.day;
              ref.read(reportsTimeRangeProvider.notifier).setRange(
                    isNewToday
                        ? DashboardTimeRange.today
                        : DashboardTimeRange.custom,
                  );
            },
            onNext: () {
              ref.read(reportsDateProvider.notifier).nextDay();
              final newDate = ref.read(reportsDateProvider);
              final isNewToday = newDate.year == now.year &&
                  newDate.month == now.month &&
                  newDate.day == now.day;
              ref.read(reportsTimeRangeProvider.notifier).setRange(
                    isNewToday
                        ? DashboardTimeRange.today
                        : DashboardTimeRange.custom,
                  );
            },
            onPickDate: () => _pickDate(context, ref),
          ),
          Tooltip(
            message: 'Export data   ⌘E',
            child: ElevatedButton.icon(
              onPressed: () => ExportDialog.show(context),
              icon: const Icon(
                Icons.file_download_outlined,
                size: IconSizes.md,
              ),
              label: const Text('Export Data'),
            ),
          ),
          IconButton(
            onPressed: () => ref.invalidate(sessionHistoryProvider),
            icon: const Icon(Icons.refresh, size: IconSizes.md),
            tooltip: 'Refresh session log',
            style: IconButton.styleFrom(
              minimumSize:
                  const Size(ControlSizes.standard, ControlSizes.standard),
              maximumSize:
                  const Size(ControlSizes.standard, ControlSizes.standard),
              padding: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(
                  borderRadius: Radii.mdAll),
            ),
          ),
        ],
        child: sessionsAsync.when(
          loading: () => const SkeletonList(itemCount: 4, itemHeight: 96),
          error: (err, stack) => ErrorState(
            title: 'Could not load sessions',
            error: err,
            onRetry: () => ref.invalidate(sessionHistoryProvider),
          ),
          data: (records) {
            if (records.isEmpty) {
              return const EmptyState(
                icon: Icons.history_toggle_off,
                title: 'No sessions recorded in this period',
                message:
                    'Start a timer on a work item, or navigate dates to '
                    'see earlier sessions.',
              );
            }

            // Group by local calendar day, newest first. The provider
            // already returns records ordered by start time, so each day's
            // list keeps that order.
            final grouped = <DateTime, List<SessionExportRecord>>{};
            for (final record in records) {
              final local = record.session.startTime.toLocal();
              final day = DateTime(local.year, local.month, local.day);
              grouped.putIfAbsent(day, () => []).add(record);
            }
            final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

            final rangeTotal = records.fold<Duration>(
              Duration.zero,
              (sum, record) => sum + record.netActiveDuration,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RangeSummary(
                  sessionCount: records.length,
                  dayCount: days.length,
                  total: rangeTotal,
                ),
                const SizedBox(height: Spacing.lg),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: Spacing.xxl),
                    itemCount: days.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Spacing.xl),
                    itemBuilder: (context, index) {
                      final day = days[index];
                      return SessionDayGroup(
                        day: day,
                        records: grouped[day]!,
                        onEdit: (record) =>
                            SessionEditDialog.show(context, record),
                        onDelete: (record) => _confirmDelete(
                          context,
                          ref,
                          record.session.id,
                          record.workItem.name,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A one-line total for everything currently in range, so the number the
/// screen exists to report is visible without scrolling.
class _RangeSummary extends StatelessWidget {
  final int sessionCount;
  final int dayCount;
  final Duration total;

  const _RangeSummary({
    required this.sessionCount,
    required this.dayCount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: Radii.mdAll,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Icon(Icons.summarize_outlined,
              size: IconSizes.md, color: colors.accent),
          const SizedBox(width: Spacing.sm),
          Text(
            'Range total',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(width: Spacing.sm),
          Text(
            TimerService.formatDuration(total, includeSeconds: false),
            style: AppTypography.numeric(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            '$sessionCount session${sessionCount == 1 ? '' : 's'} '
            'across $dayCount day${dayCount == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
