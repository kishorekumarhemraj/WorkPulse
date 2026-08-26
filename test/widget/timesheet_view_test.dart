import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';
import 'package:workpulse/features/timesheet/providers/timesheet_provider.dart';
import 'package:workpulse/features/timesheet/views/timesheet_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final range = DateRange(
    start: DateTime.utc(2026, 8, 23),
    end: DateTime.utc(2026, 8, 29, 23, 59, 59),
  );

  final costCentre = AttributeDefinition(
    id: 'def-cc',
    workspaceId: 'ws-1',
    key: 'cost_centre',
    name: 'Cost Centre',
    type: AttributeType.singleSelect,
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 1),
  );

  TimesheetData sheet({
    Duration capex = const Duration(hours: 6),
    Duration opex = const Duration(hours: 2),
    Duration unclassified = Duration.zero,
    Duration idle = const Duration(minutes: 30),
  }) {
    final net = CapexOpexSplit(
      capex: capex,
      opex: opex,
      unclassified: unclassified,
    );
    final gross = CapexOpexSplit(
      capex: capex + idle,
      opex: opex,
      unclassified: unclassified,
    );

    TimesheetRow row(String id, String label, {String? code}) => TimesheetRow(
          id: id,
          label: label,
          colorHex: '#0A84FF',
          code: code,
          net: net,
          gross: gross,
          sessionCount: 2,
        );

    // Two rows per table, and a grand total that is their sum — the screen's
    // own invariant is that every table reconciles to the same figure.
    return TimesheetData(
      range: range,
      total: TimesheetRow(
        id: '__total__',
        label: 'Total',
        net: net + net,
        gross: gross + gross,
        sessionCount: 4,
      ),
      projectRows: [
        row('proj-1', 'Apollo', code: 'PRJ-1042'),
        row('proj-2', 'Zephyr'),
      ],
      attributeSections: [
        TimesheetAttributeSection(
          definition: costCentre,
          rows: [row('CC-100', 'CC-100'), row('CC-200', 'CC-200')],
        ),
      ],
      sessionCount: 4,
    );
  }

  Future<void> pumpSheet(
    WidgetTester tester,
    TimesheetData data, {
    ThemeData? theme,
  }) async {
    // Tall enough that the summary and both tables are laid out, so the
    // finders below are not really testing ListView's laziness.
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timesheetDataProvider.overrideWith((ref) => Future.value(data)),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.darkTheme,
          home: const TimesheetView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('TimesheetView', () {
    testWidgets('reports CAPEX and OPEX per project and per attribute',
        (tester) async {
      await pumpSheet(tester, sheet());

      expect(find.text('Time Sheet'), findsOneWidget);
      expect(find.text('By project'), findsOneWidget);
      expect(find.text('By Cost Centre'), findsOneWidget);
      expect(find.text('Apollo'), findsOneWidget);
      expect(find.text('CC-100'), findsOneWidget);

      // Decimal hours, because that is what a timesheet form accepts.
      expect(find.text('6.00'), findsWidgets);
      expect(find.text('2.00'), findsWidgets);
    });

    testWidgets('the project table shows each project\'s timesheet code',
        (tester) async {
      await pumpSheet(tester, sheet());

      // The code column belongs to the project table only — an attribute
      // value is not booked against anything itself.
      expect(find.text('CODE'), findsOneWidget);
      expect(find.text('PRJ-1042'), findsOneWidget);
      // A project without one says so rather than showing an empty cell.
      expect(find.text('No code'), findsOneWidget);
    });

    testWidgets('the Gross toggle re-reports the same rows with idle included',
        (tester) async {
      await pumpSheet(tester, sheet());

      // Net CAPEX is 6.00 a row; Gross adds the half hour of idle back.
      expect(find.text('6.50'), findsNothing);

      await tester.tap(find.text('Gross hours'));
      await tester.pumpAndSettle();

      expect(find.text('6.50'), findsWidgets);
    });

    testWidgets('the Unclassified column appears only when there is any',
        (tester) async {
      await pumpSheet(tester, sheet());
      expect(find.text('UNCLASSIFIED'), findsNothing);

      await pumpSheet(
        tester,
        sheet(unclassified: const Duration(hours: 1)),
      );
      // Both the summary tile and the table column appear, and the tile
      // says what the bucket means.
      expect(find.text('UNCLASSIFIED'), findsWidgets);
      expect(
        find.textContaining('Sessions with no category'),
        findsOneWidget,
      );
    });

    testWidgets('every panel sits on the standard card surface, not a tint',
        (tester) async {
      await pumpSheet(tester, sheet(), theme: AppTheme.lightTheme);

      // The summary and both tables. Going through AppCard is what keeps
      // this screen on the same surface as the rest of the app.
      expect(find.byType(AppCard), findsNWidgets(3));

      // Pinned in the light theme on purpose: `colors.card` is a near-white
      // tint in dark mode, so a card painted with the wrong token looked
      // correct there and turned the whole screen grey here.
      final surfaces = tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(surfaces, isNotEmpty);
      for (final surface in surfaces) {
        final decoration = surface.decoration as BoxDecoration?;
        expect(
          decoration?.color,
          WorkPulseColors.light.surface,
          reason: 'A Time Sheet card is not on the card surface',
        );
      }
    });

    testWidgets('an empty range explains itself instead of showing zeroes',
        (tester) async {
      await pumpSheet(
        tester,
        TimesheetData(
          range: range,
          total: const TimesheetRow(id: '__total__', label: 'Total'),
        ),
      );

      expect(find.text('No tracked time in this period'), findsOneWidget);
      expect(find.text('By project'), findsNothing);
    });
  });
}
