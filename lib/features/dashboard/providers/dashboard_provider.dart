import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/work_pattern_model.dart';
import 'package:workpulse/domain/services/analytics_service.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(
    sessionRepository: ref.watch(sessionRepositoryProvider),
    workItemRepository: ref.watch(workItemRepositoryProvider),
    projectRepository: ref.watch(projectRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
    tagRepository: ref.watch(tagRepositoryProvider),
    personRepository: ref.watch(personRepositoryProvider),
    attributeRepository: ref.watch(attributeRepositoryProvider),
    idlePeriodRepository: ref.watch(idlePeriodRepositoryProvider),
  );
});

final selectedTimeRangeProvider =
    NotifierProvider<SelectedTimeRangeNotifier, DashboardTimeRange>(
  SelectedTimeRangeNotifier.new,
);

class SelectedTimeRangeNotifier extends Notifier<DashboardTimeRange> {
  @override
  DashboardTimeRange build() => DashboardTimeRange.today;

  void setRange(DashboardTimeRange range) => state = range;
}

final dashboardDateProvider = NotifierProvider<DashboardDateNotifier, DateTime>(
  DashboardDateNotifier.new,
);

class DashboardDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }

  void previousDay() {
    state = DateTime(state.year, state.month, state.day - 1);
  }

  void nextDay() {
    state = DateTime(state.year, state.month, state.day + 1);
  }

  void goToToday() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, now.day);
  }
}

final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  final timeRange = ref.watch(selectedTimeRangeProvider);
  final selectedDate = ref.watch(dashboardDateProvider);
  final analyticsService = ref.watch(analyticsServiceProvider);

  // Invalidate in real-time when running, or when active session starts/stops/switches
  ref.watch(timerProvider.select((s) => s.value?.isRunning == true
      ? s.value?.elapsed.inSeconds
      : s.value?.activeSession?.id));

  DateRange calculatedRange;
  switch (timeRange) {
    case DashboardTimeRange.today:
      final now = DateTime.now();
      final localStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final localEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      calculatedRange =
          DateRange(start: localStart.toUtc(), end: localEnd.toUtc());
      break;
    case DashboardTimeRange.thisWeek:
      calculatedRange = DashboardTimeRange.thisWeek.toDateRange();
      break;
    case DashboardTimeRange.thisMonth:
      calculatedRange = DashboardTimeRange.thisMonth.toDateRange();
      break;
    case DashboardTimeRange.custom:
      final localStart = DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
      final localEnd = DateTime(selectedDate.year, selectedDate.month,
          selectedDate.day, 23, 59, 59, 999);
      calculatedRange = DateRange(
        start: localStart.toUtc(),
        end: localEnd.toUtc(),
      );
      break;
  }

  return analyticsService.getDashboardData(
    workspaceId: workspace.id,
    range: calculatedRange,
  );
});

/// How far back the insights panel looks.
///
/// Separate from [selectedTimeRangeProvider] on purpose: the breakdowns answer
/// "where did today go", the pattern scan answers "what keeps happening", and
/// the second question needs weeks of history to have an answer at all.
final patternWindowProvider =
    NotifierProvider<PatternWindowNotifier, PatternWindow>(
  PatternWindowNotifier.new,
);

class PatternWindowNotifier extends Notifier<PatternWindow> {
  @override
  PatternWindow build() => PatternWindow.oneMonth;

  void setWindow(PatternWindow window) => state = window;
}

final workPatternReportProvider =
    FutureProvider<WorkPatternReport>((ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  final window = ref.watch(patternWindowProvider);
  final analyticsService = ref.watch(analyticsServiceProvider);

  // Recompute when a session is committed, but *not* on every tick of the
  // running timer: the scan reads weeks of history and ignores the in-flight
  // session anyway.
  ref.watch(timerProvider.select((s) => s.value?.activeSession?.id));

  return analyticsService.getWorkPatternReport(
    workspaceId: workspace.id,
    window: window,
  );
});
