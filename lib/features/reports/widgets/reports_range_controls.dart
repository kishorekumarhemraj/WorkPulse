import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/widgets/date_stepper.dart';
import 'package:workpulse/core/widgets/segmented_control.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';

/// The range controls shared by the reporting screens.
///
/// The Time Log and the Time Sheet look at the same window through the same
/// two providers, so they also share the controls that drive it — a user who
/// picks last week on one screen and switches to the other is still looking
/// at last week.

/// The header line describing the selected window.
String formatReportsRangeSubtitle(
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
  final currentDate = ref.read(reportsDateProvider);
  final now = DateTime.now();

  final picked = await showDatePicker(
    context: context,
    initialDate: currentDate,
    firstDate: DateTime(now.year - 5),
    lastDate: DateTime(now.year + 2),
  );

  if (picked == null) return;

  ref.read(reportsDateProvider.notifier).setDate(picked);
  final isToday = picked.year == now.year &&
      picked.month == now.month &&
      picked.day == now.day;
  ref.read(reportsTimeRangeProvider.notifier).setRange(
        isToday ? DashboardTimeRange.today : DashboardTimeRange.custom,
      );
}

/// Today / This Week / This Month / a specific date.
class ReportsRangePicker extends ConsumerWidget {
  const ReportsRangePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(reportsTimeRangeProvider);

    return AppSegmentedControl<DashboardTimeRange>(
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
        SegmentOption(value: DashboardTimeRange.thisWeek, label: 'This Week'),
        SegmentOption(value: DashboardTimeRange.thisMonth, label: 'This Month'),
        SegmentOption(value: DashboardTimeRange.custom, label: 'Date'),
      ],
    );
  }
}

/// Previous day / the selected day / next day.
class ReportsDateStepper extends ConsumerWidget {
  const ReportsDateStepper({super.key});

  void _syncRangeToSelectedDate(WidgetRef ref) {
    final now = DateTime.now();
    final newDate = ref.read(reportsDateProvider);
    final isNewToday = newDate.year == now.year &&
        newDate.month == now.month &&
        newDate.day == now.day;
    ref.read(reportsTimeRangeProvider.notifier).setRange(
          isNewToday ? DashboardTimeRange.today : DashboardTimeRange.custom,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(reportsDateProvider);

    return AppDateStepper(
      label: _formatDateButtonLabel(selectedDate),
      onPrevious: () {
        ref.read(reportsDateProvider.notifier).previousDay();
        _syncRangeToSelectedDate(ref);
      },
      onNext: () {
        ref.read(reportsDateProvider.notifier).nextDay();
        _syncRangeToSelectedDate(ref);
      },
      onPickDate: () => _pickDate(context, ref),
    );
  }
}
