import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/features/dashboard/providers/dashboard_provider.dart';
import 'package:workpulse/features/dashboard/views/dashboard_view.dart';
import 'package:workpulse/features/dashboard/widgets/daily_activity_chart.dart';
import 'package:workpulse/features/dashboard/widgets/metric_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockRange = DateRange(
    start: DateTime.utc(2026, 8, 23, 0, 0),
    end: DateTime.utc(2026, 8, 23, 23, 59),
  );

  const mockSummary = AnalyticsSummary(
    totalTrackedDuration: Duration(hours: 4, minutes: 30),
    totalActiveDuration: Duration(hours: 4, minutes: 0),
    totalIdleDuration: Duration(minutes: 30),
    sessionCount: 5,
    taskCount: 3,
  );

  const mockProjectBreakdown = [
    BreakdownItem(
      id: 'proj-1',
      name: 'Mobile App Refactor',
      colorHex: '#0A84FF',
      duration: Duration(hours: 2, minutes: 30),
      percentage: 62.5,
      sessionCount: 3,
    ),
    BreakdownItem(
      id: 'proj-2',
      name: 'Backend API',
      colorHex: '#30D158',
      duration: Duration(hours: 1, minutes: 30),
      percentage: 37.5,
      sessionCount: 2,
    ),
  ];

  const mockCategoryBreakdown = [
    BreakdownItem(
      id: 'cat-1',
      name: 'Engineering',
      iconName: 'code',
      colorHex: '#30D158',
      duration: Duration(hours: 4, minutes: 0),
      percentage: 100.0,
      sessionCount: 5,
    ),
  ];

  const mockWorkItemBreakdown = [
    BreakdownItem(
      id: 'task-1',
      name: 'Implement OAuth 2.0 PKCE',
      colorHex: '#0A84FF',
      duration: Duration(hours: 2, minutes: 0),
      percentage: 50.0,
      sessionCount: 2,
    ),
  ];

  final mockDailyActivity = [
    DailyActivityItem(
      date: DateTime.utc(2026, 8, 23),
      activeDuration: const Duration(hours: 4),
      idleDuration: const Duration(minutes: 30),
      sessionCount: 5,
    ),
  ];

  final mockHourlyActivity = List.generate(
    24,
    (h) => HourlyActivityItem(
      hour: h,
      activeDuration: h == 10 ? const Duration(minutes: 45) : Duration.zero,
      idleDuration: h == 10 ? const Duration(minutes: 15) : Duration.zero,
      sessionCount: h == 10 ? 1 : 0,
    ),
  );

  final mockDashboardData = DashboardData(
    range: mockRange,
    summary: mockSummary,
    projectBreakdown: mockProjectBreakdown,
    categoryBreakdown: mockCategoryBreakdown,
    workItemBreakdown: mockWorkItemBreakdown,
    dailyActivity: mockDailyActivity,
    hourlyActivity: mockHourlyActivity,
  );

  group('DashboardView UI Widget Tests', () {
    testWidgets(
        'renders header, metric cards, range filters, and breakdown lists',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardDataProvider
                .overrideWith((ref) => Future.value(mockDashboardData)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const DashboardView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header assertions
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);

      // KPI Metric Cards. Durations are scoped to their own card: the same
      // figure legitimately appears again in breakdown rows and in the group
      // totals the breakdown headers now show, so a global count would be
      // brittle without testing anything extra.
      Finder metricValue(String title, String value) => find.descendant(
            of: find.ancestor(
              of: find.text(title),
              matching: find.byType(MetricCard),
            ),
            matching: find.text(value),
          );

      expect(find.text('Total Tracked'), findsOneWidget);
      expect(metricValue('Total Tracked', '04:30'), findsOneWidget);
      expect(find.text('Net Focus Time'), findsOneWidget);
      expect(metricValue('Net Focus Time', '04:00'), findsOneWidget);
      expect(find.text('Idle Time'), findsOneWidget);
      expect(metricValue('Idle Time', '00:30'), findsOneWidget);
      expect(find.text('Active Tasks'), findsOneWidget);
      expect(metricValue('Active Tasks', '3'), findsOneWidget);

      // Breakdown Cards assertions
      expect(find.text('Time by Project'), findsOneWidget);
      expect(find.text('Mobile App Refactor'), findsOneWidget);
      expect(find.text('Backend API'), findsOneWidget);

      expect(find.text('Time by Category'), findsOneWidget);
      expect(find.text('Engineering'), findsOneWidget);

      expect(find.text('Top Tasks Tracked'), findsOneWidget);
      expect(find.text('Implement OAuth 2.0 PKCE'), findsOneWidget);
    });

    testWidgets('a bar states its active time without needing a hover',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardDataProvider
                .overrideWith((ref) => Future.value(mockDashboardData)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const DashboardView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The 10am bar holds 45 minutes of active time. Reading it used to
      // mean putting a mouse on the bar and waiting for the tooltip.
      expect(find.text('00:45'), findsOneWidget);
    });

    testWidgets('tapping previous and next day updates dashboardDateProvider',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final container = ProviderContainer(
        overrides: [
          dashboardDataProvider
              .overrideWith((ref) => Future.value(mockDashboardData)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const DashboardView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(container.read(dashboardDateProvider), today);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);

      // Tap This Week
      await tester.tap(find.text('This Week'));
      await tester.pumpAndSettle();
      expect(container.read(selectedTimeRangeProvider),
          DashboardTimeRange.thisWeek);

      // Tap This Month
      await tester.tap(find.text('This Month'));
      await tester.pumpAndSettle();
      expect(container.read(selectedTimeRangeProvider),
          DashboardTimeRange.thisMonth);

      // Tap previous day
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();

      final yesterday = DateTime(today.year, today.month, today.day - 1);
      expect(container.read(dashboardDateProvider), yesterday);
      expect(
          container.read(selectedTimeRangeProvider), DashboardTimeRange.custom);

      // Tap Today tab to return to today
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(container.read(dashboardDateProvider), today);
      expect(
          container.read(selectedTimeRangeProvider), DashboardTimeRange.today);

      // Tap next day
      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();

      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      expect(container.read(dashboardDateProvider), tomorrow);
      expect(
          container.read(selectedTimeRangeProvider), DashboardTimeRange.custom);
    });

    test('getHourlyBarColor thresholds: >45m green, 15-45m amber, <15m red',
        () {
      const colors = WorkPulseColors.dark;

      // > 45 mins -> green (successFill)
      expect(
        DailyActivityChart.getHourlyBarColor(
            const Duration(minutes: 46), colors),
        colors.successFill,
      );
      expect(
        DailyActivityChart.getHourlyBarColor(
            const Duration(minutes: 60), colors),
        colors.successFill,
      );

      // 15 - 45 mins -> amber (warningFill)
      expect(
        DailyActivityChart.getHourlyBarColor(
            const Duration(minutes: 45), colors),
        colors.warningFill,
      );
      expect(
        DailyActivityChart.getHourlyBarColor(
            const Duration(minutes: 30), colors),
        colors.warningFill,
      );
      expect(
        DailyActivityChart.getHourlyBarColor(
            const Duration(minutes: 15), colors),
        colors.warningFill,
      );

      // < 15 mins -> red (dangerFill)
      expect(
        DailyActivityChart.getHourlyBarColor(
            const Duration(minutes: 14), colors),
        colors.dangerFill,
      );
      expect(
        DailyActivityChart.getHourlyBarColor(
            const Duration(minutes: 5), colors),
        colors.dangerFill,
      );
      expect(
        DailyActivityChart.getHourlyBarColor(Duration.zero, colors),
        colors.dangerFill,
      );
    });

    test('getDailyBarColor thresholds: >=8.5h green, 4-8.5h amber, <4h red',
        () {
      const colors = WorkPulseColors.dark;

      // >= 8.5 hours -> green (successFill)
      expect(
        DailyActivityChart.getDailyBarColor(
            const Duration(hours: 8, minutes: 30), colors),
        colors.successFill,
      );
      expect(
        DailyActivityChart.getDailyBarColor(const Duration(hours: 9), colors),
        colors.successFill,
      );

      // >= 4.0h and < 8.5h -> amber (warningFill)
      expect(
        DailyActivityChart.getDailyBarColor(
            const Duration(hours: 8, minutes: 29), colors),
        colors.warningFill,
      );
      expect(
        DailyActivityChart.getDailyBarColor(const Duration(hours: 4), colors),
        colors.warningFill,
      );

      // < 4 hours -> red (dangerFill)
      expect(
        DailyActivityChart.getDailyBarColor(
            const Duration(hours: 3, minutes: 59), colors),
        colors.dangerFill,
      );
      expect(
        DailyActivityChart.getDailyBarColor(const Duration(hours: 1), colors),
        colors.dangerFill,
      );
      expect(
        DailyActivityChart.getDailyBarColor(Duration.zero, colors),
        colors.dangerFill,
      );
    });

    testWidgets(
        'Hourly and Daily charts render their respective threshold legends',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  DailyActivityChart(
                    isHourly: true,
                    hourlyActivities: mockHourlyActivity,
                  ),
                  DailyActivityChart(
                    isHourly: false,
                    activities: mockDailyActivity,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Hourly legends
      expect(find.text('>45m'), findsOneWidget);
      expect(find.text('15–45m'), findsOneWidget);
      expect(find.text('<15m'), findsOneWidget);

      // Daily legends
      expect(find.text('≥8.5h'), findsOneWidget);
      expect(find.text('4–8.5h'), findsOneWidget);
      expect(find.text('<4h'), findsOneWidget);

      // Idle swatches (one for each chart)
      expect(find.text('Idle'), findsNWidgets(2));
    });
  });
}
