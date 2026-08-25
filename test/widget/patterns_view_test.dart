import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/work_pattern_model.dart';
import 'package:workpulse/features/dashboard/providers/dashboard_provider.dart';
import 'package:workpulse/features/patterns/views/patterns_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final window = DateRange(
    start: DateTime.utc(2026, 7, 27),
    end: DateTime.utc(2026, 8, 25, 23, 59),
  );

  const rhythm = FocusRhythm(
    peakFocusHours: [10, 11],
    longestUnbrokenBlock: Duration(minutes: 95),
    medianSessionLength: Duration(minutes: 25),
    deepWorkTotal: Duration(hours: 6),
    deepWorkShare: 0.3,
    switchesPerTrackedDay: 4.8,
    trackedDayCount: 12,
  );

  const fragmented = WorkPatternInsight(
    id: 'fragmented:task-1',
    action: InsightAction.reclaim,
    severity: InsightSeverity.high,
    subject: PatternSubject.workItem,
    subjectId: 'task-1',
    title: 'Release checklist arrives in fragments',
    finding: 'On two days you came back to it nine times.',
    recommendation: 'Give it one booked block instead of nine re-entries.',
    timeInvolved: Duration(hours: 1, minutes: 20),
    evidence: [
      InsightEvidence('Visits', '9'),
      InsightEvidence('Median visit', '9m'),
    ],
  );

  const routine = WorkPatternInsight(
    id: 'routine-task:task-2',
    action: InsightAction.delegate,
    severity: InsightSeverity.notable,
    subject: PatternSubject.workItem,
    subjectId: 'task-2',
    title: 'Weekly status pack repeats and never goes deep',
    finding: 'It came up on ten of twelve tracked days.',
    recommendation: 'Write the steps down once and it stops being yours.',
    timeInvolved: Duration(hours: 4, minutes: 10),
  );

  const atRisk = WorkPatternInsight(
    id: 'at-risk:task-3',
    action: InsightAction.plan,
    severity: InsightSeverity.notable,
    subject: PatternSubject.workItem,
    subjectId: 'task-3',
    title: 'Migration write-up has been quiet for 15 days',
    finding: 'Two and a half hours went in, then nothing since 10 Aug.',
    recommendation: 'Give it a slot this week or close it out.',
    timeInvolved: Duration(hours: 2, minutes: 30),
  );

  const held = WorkPatternInsight(
    id: 'deep-work-held',
    action: InsightAction.sustain,
    severity: InsightSeverity.informational,
    subject: PatternSubject.schedule,
    title: 'Deep work is up 8 points on the window before',
    finding: '6h in stretches of 45m or more.',
    recommendation: 'Defend whatever is buying you these blocks.',
    timeInvolved: Duration(hours: 6),
  );

  WorkPatternReport report({
    List<WorkPatternInsight> insights = const [
      held,
      fragmented,
      routine,
      atRisk,
    ],
    int sessionCount = 24,
    FocusRhythm focus = rhythm,
  }) =>
      WorkPatternReport(
        window: window,
        lookback: PatternWindow.oneMonth,
        totalActive: const Duration(hours: 20),
        sessionCount: sessionCount,
        rhythm: focus,
        insights: insights,
      );

  Widget host(ProviderContainer container) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const PatternsView(),
        ),
      );

  ProviderContainer containerFor(WorkPatternReport value) {
    return ProviderContainer(
      overrides: [
        workPatternReportProvider.overrideWith((ref) => Future.value(value)),
      ],
    );
  }

  Future<void> pumpView(
    WidgetTester tester,
    ProviderContainer container, {
    Size size = const Size(1280, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(container));
    await tester.pumpAndSettle();
  }

  group('PatternsView Widget Tests', () {
    testWidgets('renders page header, rhythm strip, and action lanes',
        (tester) async {
      final container = containerFor(report());
      addTearDown(container.dispose);

      await pumpView(tester, container);

      expect(find.text('Patterns & Signals'), findsOneWidget);
      expect(
        find.textContaining('24 sessions over 12 tracked days · 20h active'),
        findsOneWidget,
      );

      // Continue leads: a page that only ever lists faults stops being opened.
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Reclaim'), findsOneWidget);
      expect(find.text('Delegate'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);

      expect(find.text(held.title), findsOneWidget);
      expect(find.text(fragmented.title), findsOneWidget);
      expect(find.text(routine.title), findsOneWidget);
      expect(find.text(atRisk.title), findsOneWidget);

      expect(find.text(fragmented.recommendation), findsOneWidget);
      expect(find.text(routine.recommendation), findsOneWidget);
      expect(find.text('Copy Findings'), findsOneWidget);
    });

    testWidgets('summarises focus rhythm stats in the rhythm strip',
        (tester) async {
      final container = containerFor(report());
      addTearDown(container.dispose);

      await pumpView(tester, container);

      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('Longest stretch'), findsOneWidget);
      expect(find.text('1h 35m'), findsOneWidget);
      expect(find.text('Sessions a day'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('Focus window'), findsOneWidget);
      expect(find.text('10am–12pm'), findsOneWidget);
    });

    testWidgets('expands and collapses evidence chips on demand',
        (tester) async {
      final container = containerFor(report(insights: const [fragmented]));
      addTearDown(container.dispose);

      await pumpView(tester, container);

      expect(find.text('Visits'), findsNothing);

      await tester.tap(find.text('Show numbers'));
      await tester.pumpAndSettle();

      expect(find.text('Visits'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('Median visit'), findsOneWidget);

      await tester.tap(find.text('Hide numbers'));
      await tester.pumpAndSettle();

      expect(find.text('Visits'), findsNothing);
    });

    testWidgets(
        'changing lookback segmented control updates patternWindowProvider',
        (tester) async {
      final container = containerFor(report());
      addTearDown(container.dispose);

      await pumpView(tester, container);

      expect(container.read(patternWindowProvider), PatternWindow.oneMonth);

      await tester.tap(find.text('90 days'));
      await tester.pumpAndSettle();

      expect(container.read(patternWindowProvider), PatternWindow.oneQuarter);

      await tester.tap(find.text('14 days'));
      await tester.pumpAndSettle();

      expect(container.read(patternWindowProvider), PatternWindow.twoWeeks);
    });

    testWidgets('displays empty state when no session history exists',
        (tester) async {
      final container = containerFor(
        report(insights: const [], sessionCount: 0, focus: const FocusRhythm()),
      );
      addTearDown(container.dispose);

      await pumpView(tester, container);

      expect(find.text('Nothing to read yet'), findsOneWidget);
      expect(find.text('Reclaim'), findsNothing);
    });

    testWidgets('displays clean state when history exists but no flags raised',
        (tester) async {
      final container = containerFor(report(insights: const []));
      addTearDown(container.dispose);

      await pumpView(tester, container);

      expect(find.text('No patterns worth flagging'), findsOneWidget);
      expect(find.text('Deep work'), findsOneWidget);
    });

    testWidgets('handles error state with retry button', (tester) async {
      final container = ProviderContainer(
        overrides: [
          workPatternReportProvider.overrideWith(
            (ref) => Future<WorkPatternReport>.error(
              StateError('database unavailable'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await pumpView(tester, container);

      expect(find.text('Could not scan for patterns'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    for (final width in <double>[1600, 1440, 1320, 1200, 1000, 860, 640]) {
      testWidgets('renders responsively without overflow at ${width.toInt()}px',
          (tester) async {
        final container = containerFor(report());
        addTearDown(container.dispose);

        await pumpView(tester, container, size: Size(width, 2200));

        expect(
          tester.takeException(),
          isNull,
          reason: 'the patterns page overflowed at ${width.toInt()}px',
        );
      });
    }
  });
}
