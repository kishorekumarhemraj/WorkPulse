import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/features/dashboard/providers/dashboard_provider.dart';
import 'package:workpulse/features/dashboard/views/dashboard_view.dart';

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

  final mockDashboardData = DashboardData(
    range: mockRange,
    summary: mockSummary,
    projectBreakdown: mockProjectBreakdown,
    categoryBreakdown: mockCategoryBreakdown,
    workItemBreakdown: mockWorkItemBreakdown,
    dailyActivity: mockDailyActivity,
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
      expect(find.text('Dashboard & Insights'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      // KPI Metric Cards assertions
      expect(find.text('Total Tracked'), findsOneWidget);
      expect(find.text('04:30'), findsOneWidget);
      expect(find.text('Net Focus Time'), findsOneWidget);
      expect(find.text('04:00'),
          findsNWidgets(2)); // In metric card and category card
      expect(find.text('Idle Time'), findsOneWidget);
      expect(find.text('00:30'), findsOneWidget);
      expect(find.text('Active Tasks'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Breakdown Cards assertions
      expect(find.text('Time by Project'), findsOneWidget);
      expect(find.text('Mobile App Refactor'), findsOneWidget);
      expect(find.text('Backend API'), findsOneWidget);

      expect(find.text('Time by Category'), findsOneWidget);
      expect(find.text('Engineering'), findsOneWidget);

      expect(find.text('Top Tasks Tracked'), findsOneWidget);
      expect(find.text('Implement OAuth 2.0 PKCE'), findsOneWidget);
    });

    testWidgets('tapping range pills updates selectedTimeRangeProvider',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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

      await tester.tap(find.text('This Week'));
      await tester.pumpAndSettle();

      expect(container.read(selectedTimeRangeProvider),
          DashboardTimeRange.thisWeek);

      await tester.tap(find.text('This Month'));
      await tester.pumpAndSettle();

      expect(container.read(selectedTimeRangeProvider),
          DashboardTimeRange.thisMonth);
    });
  });
}
