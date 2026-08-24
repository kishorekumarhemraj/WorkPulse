import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/reports/views/export_dialog.dart';
import 'package:workpulse/features/reports/views/session_edit_dialog.dart';
import 'package:workpulse/features/reports/views/session_history_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 8, 23, 14, 0);

  final mockSession = Session(
    id: 'sess-1',
    workItemId: 'task-1',
    startTime: now.subtract(const Duration(minutes: 60)),
    endTime: now,
    createdAt: now.subtract(const Duration(minutes: 60)),
  );

  final mockWorkItem = WorkItem(
    id: 'task-1',
    workspaceId: 'ws-1',
    projectId: 'proj-1',
    categoryId: 'cat-1',
    name: 'Build Export & Hardening Feature',
    notes: 'Implemented CSV exporter and tests',
    createdAt: now,
    updatedAt: now,
  );

  final mockProject = Project(
    id: 'proj-1',
    workspaceId: 'ws-1',
    name: 'WorkPulse Core',
    colorHex: '#0A84FF',
    createdAt: now,
    updatedAt: now,
  );

  final mockCategory = Category(
    id: 'cat-1',
    workspaceId: 'ws-1',
    name: 'Engineering',
    iconName: 'code',
    createdAt: now,
    updatedAt: now,
  );

  final mockRecord = SessionExportRecord(
    session: mockSession,
    workItem: mockWorkItem,
    project: mockProject,
    category: mockCategory,
    grossDuration: const Duration(minutes: 60),
    idleDuration: Duration.zero,
    netActiveDuration: const Duration(minutes: 60),
  );

  group('Export UI Widget Tests', () {
    testWidgets(
        'ExportDialog renders title, range pills, formats, and handles copy',
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
          home: const Scaffold(body: ExportDialog()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Export Work Data'), findsOneWidget);
      expect(find.text('PDF (Visual Work Report)'), findsOneWidget);
      expect(find.text('CSV (Spreadsheet / Excel)'), findsOneWidget);
      expect(find.text('JSON (Structured Backup)'), findsOneWidget);
      expect(find.text('Export & Open PDF'), findsOneWidget);

      // Tap CSV format
      await tester.tap(find.text('CSV (Spreadsheet / Excel)'));
      await tester.pumpAndSettle();

      expect(find.text('Copy to Clipboard'), findsOneWidget);

      // Tap JSON format
      await tester.tap(find.text('JSON (Structured Backup)'));
      await tester.pumpAndSettle();

      expect(find.text('JSON (Structured Backup)'), findsOneWidget);
      expect(find.text('Copy to Clipboard'), findsOneWidget);
    });

    testWidgets(
        'SessionHistoryView renders header, export button, and session logs',
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
            sessionHistoryProvider
                .overrideWith((ref) => Future.value([mockRecord])),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SessionHistoryView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Time Log'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.text('Export Data'), findsOneWidget);
      expect(find.text('Build Export & Hardening Feature'), findsOneWidget);
      expect(find.text('WorkPulse Core'), findsOneWidget);
      expect(find.text('Engineering'), findsOneWidget);
      expect(find.text('01:00:00'), findsOneWidget);

      // Sessions are grouped under a day header carrying that day's total,
      // and the range total is summarised above the list, so the date is no
      // longer repeated on every row.
      expect(find.text('Range total'), findsOneWidget);
      expect(find.text('1 session across 1 day'), findsOneWidget);

      // Tap Today tab
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // Tap Next Day
      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();

      // Tap Previous Day
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'SessionEditDialog renders session details, time pickers, and notes field',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SessionEditDialog(record: mockRecord),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit Session'), findsOneWidget);
      expect(find.text('Build Export & Hardening Feature'), findsOneWidget);
      expect(find.text('Start Time'), findsOneWidget);
      expect(find.text('End Time'), findsOneWidget);
      expect(find.text('Session Notes'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });
  });
}
