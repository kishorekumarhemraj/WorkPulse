import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
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

final customDateRangeProvider =
    NotifierProvider<CustomDateRangeNotifier, DateTimeRange?>(
  CustomDateRangeNotifier.new,
);

class CustomDateRangeNotifier extends Notifier<DateTimeRange?> {
  @override
  DateTimeRange? build() => null;

  void setCustomRange(DateTimeRange? range) => state = range;
}

final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  final timeRange = ref.watch(selectedTimeRangeProvider);
  final customRange = ref.watch(customDateRangeProvider);
  final analyticsService = ref.watch(analyticsServiceProvider);

  // Invalidate when active session starts/stops/switches
  ref.watch(timerProvider.select((s) => s.value?.activeSession?.id));

  // Bridge Flutter DateTimeRange to pure-Dart DateRange for domain layer.
  // .toUtc() matters here: DateTimeRange is local wall-clock time from the
  // date picker, but start_time/end_time are always stored as UTC.
  final flutterCustomRange = customRange != null
      ? DateRange(
          start: customRange.start.toUtc(), end: customRange.end.toUtc())
      : null;
  final calculatedRange =
      timeRange.toDateRange(customRange: flutterCustomRange);

  return analyticsService.getDashboardData(
    workspaceId: workspace.id,
    range: calculatedRange,
  );
});
