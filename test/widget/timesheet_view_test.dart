import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
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
    Duration capex = const Duration(hours: 12),
    Duration opex = const Duration(hours: 4),
    Duration unclassified = Duration.zero,
    Duration idlePerSplit = const Duration(hours: 1),
  }) {
    final net = CapexOpexSplit(
      capex: capex,
      opex: opex,
      unclassified: unclassified,
    );
    final gross = CapexOpexSplit(
      capex: capex + idlePerSplit,
      opex: opex,
      unclassified: unclassified,
    );

    TimesheetRow row(String id, String label) => TimesheetRow(
          id: id,
          label: label,
          colorHex: '#0A84FF',
          net: net,
          gross: gross,
          sessionCount: 4,
        );

    return TimesheetData(
      range: range,
      total: row('__total__', 'Total'),
      projectRows: [row('proj-1', 'Apollo')],
      attributeSections: [
        TimesheetAttributeSection(
          definition: costCentre,
          rows: [row('CC-100', 'CC-100')],
        ),
      ],
      sessionCount: 4,
    );
  }

  Future<void> pumpSheet(WidgetTester tester, TimesheetData data) async {
    tester.view.physicalSize = const Size(1400, 900);
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
          theme: AppTheme.darkTheme,
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
      expect(find.text('12.00'), findsWidgets);
      expect(find.text('4.00'), findsWidgets);
    });

    testWidgets('the Gross toggle re-reports the same rows with idle included',
        (tester) async {
      await pumpSheet(tester, sheet());

      // Net: 12 CAPEX. Gross adds the hour of idle back.
      expect(find.text('13.00'), findsNothing);

      await tester.tap(find.text('Gross hours'));
      await tester.pumpAndSettle();

      expect(find.text('13.00'), findsWidgets);
    });

    testWidgets('the Unclassified column appears only when there is any',
        (tester) async {
      await pumpSheet(tester, sheet());
      expect(find.text('UNCLASSIFIED'), findsNothing);

      await pumpSheet(
        tester,
        sheet(unclassified: const Duration(hours: 2)),
      );
      // Both the summary tile and the table column appear, and the tile
      // says what the bucket means.
      expect(find.text('UNCLASSIFIED'), findsWidgets);
      expect(
        find.textContaining('Sessions with no category'),
        findsOneWidget,
      );
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
