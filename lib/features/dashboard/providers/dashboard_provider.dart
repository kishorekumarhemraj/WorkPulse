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

final dashboardDateProvider =
    NotifierProvider<DashboardDateNotifier, DateTime>(
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
  final selectedDate = ref.watch(dashboardDateProvider);
  final analyticsService = ref.watch(analyticsServiceProvider);

  // Invalidate in real-time when running, or when active session starts/stops/switches
  ref.watch(timerProvider.select((s) => s.value?.isRunning == true
      ? s.value?.elapsed.inSeconds
      : s.value?.activeSession?.id));

  // Compute 24-hour UTC DateRange for the single selected calendar day.
  final localStart =
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
  final localEnd = DateTime(
      selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59, 999);
  final calculatedRange = DateRange(
    start: localStart.toUtc(),
    end: localEnd.toUtc(),
  );

  return analyticsService.getDashboardData(
    workspaceId: workspace.id,
    range: calculatedRange,
  );
});

