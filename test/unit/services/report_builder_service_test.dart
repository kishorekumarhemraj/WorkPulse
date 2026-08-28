import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/work_report_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/report_builder_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';

void main() {
  group('ReportBuilderService Unit Tests', () {
    const builder = ReportBuilderService();

    final now = DateTime.utc(2026, 8, 24, 10, 0, 0);

    final projectA = Project(
      id: 'p1',
      workspaceId: 'ws-1',
      name: 'Auth Platform',
      colorHex: '#3B82F6',
      createdAt: now,
      updatedAt: now,
    );

    final projectB = Project(
      id: 'p2',
      workspaceId: 'ws-1',
      name: 'Billing System',
      colorHex: '#10B981',
      createdAt: now,
      updatedAt: now,
    );

    final categoryEng = Category(
      id: 'c1',
      workspaceId: 'ws-1',
      name: 'Engineering',
      iconName: 'code',
      createdAt: now,
      updatedAt: now,
    );

    final categoryDesign = Category(
      id: 'c2',
      workspaceId: 'ws-1',
      name: 'Design',
      iconName: 'brush',
      createdAt: now,
      updatedAt: now,
    );

    final tag1 = Tag(id: 't1', workspaceId: 'ws-1', name: 'release', createdAt: now);
    final person1 = Person(id: 'per1', workspaceId: 'ws-1', name: 'Alice', createdAt: now);

    final taskA = WorkItem(
      id: 'task-1',
      workspaceId: 'ws-1',
      projectId: 'p1',
      categoryId: 'c1',
      financialClassification: FinancialClassification.capex,
      name: 'Implement OAuth Login',
      createdAt: now,
      updatedAt: now,
    );

    final taskB = WorkItem(
      id: 'task-2',
      workspaceId: 'ws-1',
      projectId: 'p2',
      categoryId: 'c2',
      financialClassification: FinancialClassification.opex,
      name: 'Fix Billing Invoice Overflow',
      createdAt: now,
      updatedAt: now,
    );

    final taskUnclassified = WorkItem(
      id: 'task-3',
      workspaceId: 'ws-1',
      projectId: 'p1',
      categoryId: 'c1',
      financialClassification: FinancialClassification.none,
      name: 'Explore LLM Integration',
      createdAt: now,
      updatedAt: now,
    );

    final attrSquad = AttributeDefinition(
      id: 'attr-squad',
      workspaceId: 'ws-1',
      key: 'squad',
      name: 'Squad',
      type: AttributeType.singleSelect,
      scope: AttributeScope.task,
      reportable: true,
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );

    final session1 = Session(
      id: 'sess-1',
      workItemId: 'task-1',
      startTime: DateTime.utc(2026, 8, 24, 9, 0),
      endTime: DateTime.utc(2026, 8, 24, 11, 0),
      notes: 'Implemented refresh token handler',
      createdAt: now,
    );

    final session2 = Session(
      id: 'sess-2',
      workItemId: 'task-2',
      startTime: DateTime.utc(2026, 8, 24, 14, 0),
      endTime: DateTime.utc(2026, 8, 24, 15, 30),
      notes: 'Reviewed billing calculation',
      createdAt: now,
    );

    final session3 = Session(
      id: 'sess-3',
      workItemId: 'task-3',
      startTime: DateTime.utc(2026, 8, 25, 10, 0),
      endTime: DateTime.utc(2026, 8, 25, 11, 0),
      notes: 'Spike on prompt caching',
      createdAt: now,
    );

    final record1 = SessionExportRecord(
      session: session1,
      workItem: taskA,
      project: projectA,
      category: categoryEng,
      tags: [tag1],
      people: [person1],
      grossDuration: const Duration(hours: 2),
      idleDuration: const Duration(minutes: 15),
      netActiveDuration: const Duration(minutes: 105),
      classification: FinancialClassification.capex,
      attributeValues: {'attr-squad': 'Core Engine'},
    );

    final record2 = SessionExportRecord(
      session: session2,
      workItem: taskB,
      project: projectB,
      category: categoryDesign,
      tags: [tag1],
      grossDuration: const Duration(minutes: 90),
      idleDuration: Duration.zero,
      netActiveDuration: const Duration(minutes: 90),
      classification: FinancialClassification.opex,
      attributeValues: {'attr-squad': 'Platform'},
    );

    final record3 = SessionExportRecord(
      session: session3,
      workItem: taskUnclassified,
      project: projectA,
      category: null, // Uncategorized
      grossDuration: const Duration(hours: 1),
      idleDuration: Duration.zero,
      netActiveDuration: const Duration(hours: 1),
      classification: FinancialClassification.none,
      attributeValues: const {},
    );

    test('breakdowns strictly sum to range total net active duration', () {
      final range = DateRange(
        start: DateTime.utc(2026, 8, 24, 0, 0),
        end: DateTime.utc(2026, 8, 26, 23, 59),
      );

      final report = builder.build(
        workspaceName: 'Acme Workspace',
        authorName: 'Kishore',
        range: range,
        records: [record1, record2, record3],
        definitions: [attrSquad],
        codes: const TimesheetCodeResolver(
          codesByProject: {
            'p1': {'': 'PRJ-101'},
            'p2': {'': 'PRJ-202'},
          },
        ),
      );

      const expectedTotalNet = Duration(minutes: 105 + 90 + 60); // 255 mins
      expect(report.headline.totalNet, equals(expectedTotalNet));

      // Project sum
      final projectTotal = report.projects.fold(Duration.zero, (a, b) => a + b.duration);
      expect(projectTotal, equals(expectedTotalNet));

      // Category sum
      final catTotal = report.categories.fold(Duration.zero, (a, b) => a + b.duration);
      expect(catTotal, equals(expectedTotalNet));

      // Classification sum
      expect(report.classification.total, equals(expectedTotalNet));
      expect(report.classification.capex, equals(const Duration(minutes: 105)));
      expect(report.classification.opex, equals(const Duration(minutes: 90)));
      expect(report.classification.none, equals(const Duration(minutes: 60)));

      // Attribute breakdown sum
      expect(report.attributes.length, 1);
      final attrTotal = report.attributes.first.slices.fold(Duration.zero, (a, b) => a + b.duration);
      expect(attrTotal, equals(expectedTotalNet));

      // Timesheet codes sum
      final codeTotal = report.codes.fold(Duration.zero, (a, b) => a + b.duration);
      expect(codeTotal, equals(expectedTotalNet));
    });

    test('shares sum to 1.0 (100%) within rounding tolerance', () {
      final range = DateRange(
        start: DateTime.utc(2026, 8, 24, 0, 0),
        end: DateTime.utc(2026, 8, 26, 23, 59),
      );

      final report = builder.build(
        workspaceName: 'Acme Workspace',
        authorName: 'Kishore',
        range: range,
        records: [record1, record2, record3],
      );

      final projectShareSum = report.projects.fold(0.0, (a, b) => a + b.share);
      expect(projectShareSum, closeTo(1.0, 0.001));

      final catShareSum = report.categories.fold(0.0, (a, b) => a + b.share);
      expect(catShareSum, closeTo(1.0, 0.001));
    });

    test('uncategorized time sorts last regardless of size', () {
      final range = DateRange(
        start: DateTime.utc(2026, 8, 24, 0, 0),
        end: DateTime.utc(2026, 8, 26, 23, 59),
      );

      // Even if uncategorized has more time (10 hours) than categorized (1 hour), it sorts last
      final largeUncatRecord = SessionExportRecord(
        session: session3,
        workItem: taskUnclassified,
        project: projectA,
        category: null,
        grossDuration: const Duration(hours: 10),
        idleDuration: Duration.zero,
        netActiveDuration: const Duration(hours: 10),
        classification: FinancialClassification.none,
      );

      final report = builder.build(
        workspaceName: 'Acme Workspace',
        authorName: 'Kishore',
        range: range,
        records: [record1, largeUncatRecord],
      );

      expect(report.categories.last.isUncategorized, isTrue);
      expect(report.categories.last.label, equals('Uncategorized'));
    });

    test('midnight crossing sessions attribute duration to each day by overlap', () {
      // Session starts at 23:00 on Aug 24 and ends at 01:00 on Aug 25 (2 hours total)
      final midnightSession = Session(
        id: 'sess-midnight',
        workItemId: 'task-1',
        startTime: DateTime(2026, 8, 24, 23, 0),
        endTime: DateTime(2026, 8, 25, 1, 0),
        createdAt: now,
      );

      final midnightRecord = SessionExportRecord(
        session: midnightSession,
        workItem: taskA,
        project: projectA,
        category: categoryEng,
        grossDuration: const Duration(hours: 2),
        idleDuration: Duration.zero,
        netActiveDuration: const Duration(hours: 2),
        classification: FinancialClassification.capex,
      );

      final range = DateRange(
        start: DateTime(2026, 8, 24, 0, 0),
        end: DateTime(2026, 8, 25, 23, 59),
      );

      final report = builder.build(
        workspaceName: 'Acme Workspace',
        authorName: 'Kishore',
        range: range,
        records: [midnightRecord],
      );

      expect(report.rhythm.length, 2);
      // Day 1 (Aug 24) should have 1 hour (23:00 - 00:00)
      expect(report.rhythm[0].totalDuration, equals(const Duration(hours: 1)));
      // Day 2 (Aug 25) should have 1 hour (00:00 - 01:00)
      expect(report.rhythm[1].totalDuration, equals(const Duration(hours: 1)));
    });

    test('single-day input selects hour axis; 90-day input selects week axis', () {
      final singleDayRange = DateRange(
        start: DateTime(2026, 8, 24, 0, 0),
        end: DateTime(2026, 8, 24, 23, 59),
      );

      final singleDayReport = builder.build(
        workspaceName: 'Acme Workspace',
        authorName: 'Kishore',
        range: singleDayRange,
        records: [record1],
      );

      expect(singleDayReport.rhythmAxis, equals(RhythmAxis.hour));
      expect(singleDayReport.rhythm.length, equals(17)); // 06:00 to 22:00

      final quarterRange = DateRange(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 3, 31),
      );

      final quarterReport = builder.build(
        workspaceName: 'Acme Workspace',
        authorName: 'Kishore',
        range: quarterRange,
        records: [record1],
      );

      expect(quarterReport.rhythmAxis, equals(RhythmAxis.week));
    });

    test('empty records list produces isEmpty report with no NaN or 100%', () {
      final range = DateRange(
        start: DateTime.utc(2026, 8, 24, 0, 0),
        end: DateTime.utc(2026, 8, 24, 23, 59),
      );

      final report = builder.build(
        workspaceName: 'Acme Workspace',
        authorName: 'Kishore',
        range: range,
        records: const [],
      );

      expect(report.isEmpty, isTrue);
      expect(report.headline.totalGross, equals(Duration.zero));
      expect(report.headline.focusEfficiency, equals(0.0));
      expect(report.headline.idlePercent, equals(0.0));
      expect(report.classification.capexShare, equals(0.0));
    });
  });
}
