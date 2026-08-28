import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/time_note_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/features/notes/providers/time_notes_provider.dart';
import 'package:workpulse/features/notes/views/time_notes_view.dart';
import 'package:workpulse/features/reports/widgets/session_metadata.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

class _FakeWorkspaceNotifier extends CurrentWorkspaceNotifier {
  final Workspace _ws;
  _FakeWorkspaceNotifier(this._ws);

  @override
  Future<Workspace> build() async => _ws;
}

void main() {
  group('TimeNotesView Widget Tests', () {
    final now = DateTime.utc(2026, 8, 23, 14, 0);
    final testWorkspace = Workspace(
      id: 'ws-1',
      name: 'Default Workspace',
      createdAt: now,
      updatedAt: now,
    );

    final testProject = Project(
      id: 'proj-1',
      workspaceId: 'ws-1',
      name: 'Auth Platform',
      colorHex: '#3B82F6',
      createdAt: now,
      updatedAt: now,
    );

    final testCategory = Category(
      id: 'cat-1',
      workspaceId: 'ws-1',
      name: 'Engineering',
      iconName: 'code',
      createdAt: now,
      updatedAt: now,
    );

    final testPerson = Person(
      id: 'per-1',
      workspaceId: 'ws-1',
      name: 'Alice Smith',
      team: 'Core Engine',
      createdAt: now,
    );

    final testTask = WorkItem(
      id: 'task-1',
      workspaceId: 'ws-1',
      projectId: 'proj-1',
      categoryId: 'cat-1',
      name: 'Implement OAuth Login Flow',
      createdAt: now,
      updatedAt: now,
    );

    final session1 = Session(
      id: 'sess-1',
      workItemId: 'task-1',
      categoryId: 'cat-1',
      notes: 'Refactored token refresh interceptor and resolved edge cases',
      startTime: now.subtract(const Duration(minutes: 45)),
      endTime: now,
      createdAt: now,
    );

    final record1 = SessionExportRecord(
      session: session1,
      workItem: testTask,
      project: testProject,
      category: testCategory,
      people: [testPerson],
      grossDuration: const Duration(minutes: 45),
      idleDuration: Duration.zero,
      netActiveDuration: const Duration(minutes: 45),
      classification: FinancialClassification.capex,
    );

    final entry1 = TimeNoteEntry(
      record: record1,
      note: 'Refactored token refresh interceptor and resolved edge cases',
      source: TimeNoteSource.session,
      timestamp: session1.startTime,
      duration: const Duration(minutes: 45),
    );

    final taskGroup = TaskNoteGroup(
      workItem: testTask,
      project: testProject,
      category: testCategory,
      classification: FinancialClassification.capex,
      people: [testPerson],
      entries: [entry1],
      totalDuration: const Duration(minutes: 45),
      sessionCount: 1,
      promotedFields: const {
        SessionMetadataField.project,
        SessionMetadataField.category,
        SessionMetadataField.classification,
        SessionMetadataField.people,
      },
    );

    final dayKey = DateTime(now.year, now.month, now.day);
    final dayGroup = NotesDayGroup(
      day: dayKey,
      taskGroups: [taskGroup],
      totalDuration: const Duration(minutes: 45),
      noteCount: 1,
      taskCount: 1,
    );

    final mockReport = TimeNotesReport(
      dayGroups: [dayGroup],
      totalNotes: 1,
      totalTasks: 1,
      totalDuration: const Duration(minutes: 45),
      unnotedSessions: 0,
      isSingleDay: true,
    );

    testWidgets('TimeNotesView renders empty state when no notes exist',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentWorkspaceProvider
                .overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
            timeNotesProvider.overrideWith(
              (ref) async => const TimeNotesReport(
                dayGroups: [],
                totalNotes: 0,
                totalTasks: 0,
                totalDuration: Duration.zero,
                unnotedSessions: 0,
                isSingleDay: true,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: TimeNotesView()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No notes logged for this period'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
    });

    testWidgets(
        'TimeNotesView displays summary card, task cards, and promoted metadata',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentWorkspaceProvider
                .overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
            timeNotesProvider.overrideWith((ref) async => mockReport),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: TimeNotesView()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Summary Card metrics
      expect(find.text('NOTES'), findsOneWidget);
      expect(find.text('TASKS'), findsOneWidget);
      expect(find.text('TRACKED TIME'), findsOneWidget);

      // Associated work item
      expect(find.text('Implement OAuth Login Flow'), findsOneWidget);

      // Note text
      expect(
        find.text(
            'Refactored token refresh interceptor and resolved edge cases'),
        findsOneWidget,
      );

      // Promoted metadata in task card header
      expect(find.text('Auth Platform'), findsOneWidget);
      expect(find.text('Engineering'), findsOneWidget);
      expect(find.text('CapEx'), findsOneWidget);
      expect(find.text('Alice Smith'), findsOneWidget);
    });
  });
}
