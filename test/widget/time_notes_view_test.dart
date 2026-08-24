import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/features/notes/models/time_note_entry.dart';
import 'package:workpulse/features/notes/providers/time_notes_provider.dart';
import 'package:workpulse/features/notes/views/time_notes_view.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

class _FakeWorkspaceNotifier extends CurrentWorkspaceNotifier {
  final Workspace _ws;
  _FakeWorkspaceNotifier(this._ws);

  @override
  Future<Workspace> build() async => _ws;
}

void main() {
  group('TimeNotesView Widget Tests', () {
    final now = DateTime.now().toUtc();
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

    final testNoteEntry = TimeNoteEntry(
      session: Session(
        id: 'sess-1',
        workItemId: 'task-1',
        categoryId: 'cat-1',
        notes: 'Refactored token refresh interceptor and resolved edge cases',
        startTime: now.subtract(const Duration(minutes: 45)),
        endTime: now,
        createdAt: now,
      ),
      workItem: testTask,
      project: testProject,
      category: testCategory,
      people: [testPerson],
      note: 'Refactored token refresh interceptor and resolved edge cases',
      startTime: now.subtract(const Duration(minutes: 45)),
      duration: const Duration(minutes: 45),
    );

    testWidgets('TimeNotesView renders empty state when no notes exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentWorkspaceProvider.overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
            timeNotesProvider.overrideWith((ref) async => <DateTime, List<TimeNoteEntry>>{}),
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

    testWidgets('TimeNotesView displays note cards grouped by date with metadata chips', (tester) async {
      final dateKey = DateTime(now.year, now.month, now.day);
      final groups = <DateTime, List<TimeNoteEntry>>{
        dateKey: [testNoteEntry],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentWorkspaceProvider.overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
            timeNotesProvider.overrideWith((ref) async => groups),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: TimeNotesView()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Note text
      expect(
        find.text('Refactored token refresh interceptor and resolved edge cases'),
        findsOneWidget,
      );

      // Associated work item
      expect(find.text('Implement OAuth Login Flow'), findsOneWidget);

      // Project, Category, and Person chips
      expect(find.text('Auth Platform'), findsOneWidget);
      expect(find.text('Engineering'), findsOneWidget);
      expect(find.text('Alice Smith'), findsOneWidget);

      // Standup copy button
      expect(find.text('Copy Notes'), findsOneWidget);
    });
  });
}
