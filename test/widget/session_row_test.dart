import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/features/reports/widgets/session_metadata.dart';
import 'package:workpulse/features/reports/widgets/session_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 8, 23, 14, 0);

  final mockProject = Project(
    id: 'proj-1',
    workspaceId: 'ws-1',
    name: 'Platform Core',
    colorHex: '#0A84FF',
    timesheetCode: 'PRJ-4471',
    createdAt: now,
    updatedAt: now,
  );

  final mockCategory = Category(
    id: 'cat-1',
    workspaceId: 'ws-1',
    name: 'Development',
    iconName: 'code',
    createdAt: now,
    updatedAt: now,
  );

  final mockTag = Tag(
    id: 'tag-1',
    workspaceId: 'ws-1',
    name: 'urgent',
    colorHex: '#FF3B30',
    createdAt: now,
  );

  final mockPerson = Person(
    id: 'per-1',
    workspaceId: 'ws-1',
    name: 'Alice',
    createdAt: now,
  );

  final mockWorkItem = WorkItem(
    id: 'task-1',
    workspaceId: 'ws-1',
    projectId: 'proj-1',
    categoryId: 'cat-1',
    name: 'Payments Migration',
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('SessionRow renders metadata chips and standalone note block',
      (tester) async {
    final mockSession = Session(
      id: 'sess-1',
      workItemId: 'task-1',
      categoryId: 'cat-1',
      startTime: now.subtract(const Duration(minutes: 75)),
      endTime: now,
      tagIds: const ['tag-1'],
      peopleIds: const ['per-1'],
      notes: 'Traced double-charge issue.\nWrote failing test first.',
      createdAt: now.subtract(const Duration(minutes: 75)),
    );

    final record = SessionExportRecord(
      session: mockSession,
      workItem: mockWorkItem,
      project: mockProject,
      category: mockCategory,
      tags: [mockTag],
      people: [mockPerson],
      grossDuration: const Duration(minutes: 75),
      idleDuration: Duration.zero,
      netActiveDuration: const Duration(minutes: 75),
      classification: FinancialClassification.capex,
      attributeValues: const {'attr-1': '24.3'},
    );

    const resolver = TimesheetCodeResolver(
      codesByProject: {
        'proj-1': {'': 'PRJ-4471'},
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SessionRow(
              record: record,
              codes: resolver,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payments Migration'), findsOneWidget);
    expect(find.text('Platform Core'), findsOneWidget);
    expect(find.text('Development'), findsOneWidget);
    expect(find.text('CapEx'), findsOneWidget);
    expect(find.text('PRJ-4471'), findsOneWidget);
    expect(find.text('#urgent'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('attr-1: 24.3'), findsOneWidget);
    expect(find.byType(SessionNoteBlock), findsOneWidget);
    expect(find.textContaining('Traced double-charge issue.'), findsOneWidget);
  });

  testWidgets('SessionRow with unclassified session renders Uncategorized chip',
      (tester) async {
    final mockSession = Session(
      id: 'sess-2',
      workItemId: 'task-1',
      startTime: now.subtract(const Duration(minutes: 30)),
      endTime: now,
      createdAt: now.subtract(const Duration(minutes: 30)),
    );

    final record = SessionExportRecord(
      session: mockSession,
      workItem: mockWorkItem,
      grossDuration: const Duration(minutes: 30),
      idleDuration: Duration.zero,
      netActiveDuration: const Duration(minutes: 30),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SessionRow(
              record: record,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Uncategorized'), findsOneWidget);
    expect(find.byType(SessionNoteBlock), findsNothing);
  });
}
