import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/platform/pdf_export_handler.dart';
import 'package:workpulse/core/platform/user_info_service.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/pdf_report_service.dart';

void main() {
  group('PdfReportService & PdfExportHandler Unit Tests', () {
    late PdfReportService pdfService;

    final now = DateTime.utc(2026, 8, 25, 10, 0, 0);

    final mockProject = Project(
      id: 'proj-1',
      workspaceId: 'ws-1',
      name: 'WorkPulse macOS App',
      colorHex: '#4F46E5',
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

    final mockTag = Tag(
      id: 'tag-1',
      workspaceId: 'ws-1',
      name: 'Release',
      colorHex: '#10B981',
      createdAt: now,
    );

    final mockPerson = Person(
      id: 'person-1',
      workspaceId: 'ws-1',
      name: 'Sarah Connor',
      createdAt: now,
    );

    final mockWorkItem = WorkItem(
      id: 'task-1',
      workspaceId: 'ws-1',
      projectId: 'proj-1',
      categoryId: 'cat-1',
      name: 'Implement Executive PDF Export Feature',
      notes: 'Completed PDF generation engine with modern colorful styling',
      tagIds: ['tag-1'],
      peopleIds: ['person-1'],
      financialClassification: FinancialClassification.capex,
      createdAt: now,
      updatedAt: now,
    );

    final mockSession = Session(
      id: 'sess-1',
      workItemId: 'task-1',
      startTime: now.subtract(const Duration(hours: 2)),
      endTime: now,
      notes:
          'Engineered pure-Dart PDF layout, KPI summary grid, and timeline breakdown.',
      peopleIds: ['person-1'],
      tagIds: ['tag-1'],
      createdAt: now.subtract(const Duration(hours: 2)),
    );

    final mockRecord = SessionExportRecord(
      session: mockSession,
      workItem: mockWorkItem,
      project: mockProject,
      category: mockCategory,
      tags: [mockTag],
      people: [mockPerson],
      grossDuration: const Duration(hours: 2),
      idleDuration: const Duration(minutes: 15),
      netActiveDuration: const Duration(minutes: 105),
      classification: FinancialClassification.capex,
      attributeValues: {
        'attr-billable': 'Yes',
        'attr-ticket': 'WP-502',
      },
    );

    final mockDefinitions = [
      AttributeDefinition(
        id: 'attr-billable',
        workspaceId: 'ws-1',
        key: 'billable',
        name: 'Billable',
        type: AttributeType.boolean,
        scope: AttributeScope.task,
        enabled: true,
        reportable: true,
        createdAt: now,
        updatedAt: now,
      ),
      AttributeDefinition(
        id: 'attr-ticket',
        workspaceId: 'ws-1',
        key: 'ticket_id',
        name: 'Ticket ID',
        type: AttributeType.text,
        scope: AttributeScope.task,
        enabled: true,
        reportable: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      pdfService = const PdfReportService();
    });

    test(
        'generateReportPdf produces non-empty, valid PDF byte array with full session details',
        () async {
      final range = DateRange(
        start: DateTime.utc(2026, 8, 25, 0, 0, 0),
        end: DateTime.utc(2026, 8, 25, 23, 59, 59),
      );

      final pdfBytes = await pdfService.generateReportPdf(
        workspaceName: 'WorkPulse Workspace',
        range: range,
        records: [mockRecord],
        attributeDefinitions: mockDefinitions,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
      // PDF documents start with '%PDF-' header
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test(
        'generateReportPdf handles empty session list cleanly without throwing',
        () async {
      final range = DateRange(
        start: DateTime.utc(2026, 8, 25, 0, 0, 0),
        end: DateTime.utc(2026, 8, 25, 23, 59, 59),
      );

      final pdfBytes = await pdfService.generateReportPdf(
        workspaceName: 'WorkPulse Workspace',
        range: range,
        records: [],
      );

      expect(pdfBytes, isNotEmpty);
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('generateReportPdf supports multi-day period range', () async {
      final range = DateRange(
        start: DateTime.utc(2026, 8, 20, 0, 0, 0),
        end: DateTime.utc(2026, 8, 25, 23, 59, 59),
      );

      final pdfBytes = await pdfService.generateReportPdf(
        workspaceName: 'WorkPulse Workspace',
        range: range,
        records: [mockRecord],
      );

      expect(pdfBytes, isNotEmpty);
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test(
        'generateReportPdf verifies copy removals in uncompressed PDF output',
        () async {
      final range = DateRange(
        start: DateTime.utc(2026, 8, 20, 0, 0, 0),
        end: DateTime.utc(2026, 8, 25, 23, 59, 59),
      );

      final uncompressedPdfBytes = await pdfService.generateReportPdf(
        workspaceName: 'Acme Corp',
        userName: 'Alice Smith',
        range: range,
        records: [mockRecord],
        compress: false,
      );

      final pdfText = latin1.decode(uncompressedPdfBytes);

      // Verify removed phrases are completely absent
      expect(pdfText.contains('Prepared for Manager'), isFalse);
      expect(pdfText.contains('Generated locally for'), isFalse);
      expect(pdfText.contains('STANDUP'), isFalse);

      // Verify document metadata
      expect(pdfText.contains('WorkPulse'), isTrue);
      expect(pdfText.contains('Alice Smith'), isTrue);
    });

    test('generateReportPdf generates 200 sessions without throwing', () async {
      final range = DateRange(
        start: DateTime.utc(2026, 8, 1, 0, 0, 0),
        end: DateTime.utc(2026, 8, 30, 23, 59, 59),
      );

      final records = List.generate(
        200,
        (i) => SessionExportRecord(
          session: Session(
            id: 'sess-$i',
            workItemId: 'task-1',
            startTime: DateTime.utc(2026, 8, (i % 28) + 1, 9, 0),
            endTime: DateTime.utc(2026, 8, (i % 28) + 1, 10, 0),
            notes: 'Session $i completed successfully.',
            createdAt: now,
          ),
          workItem: mockWorkItem,
          project: mockProject,
          category: mockCategory,
          grossDuration: const Duration(hours: 1),
          idleDuration: Duration.zero,
          netActiveDuration: const Duration(hours: 1),
          classification: FinancialClassification.capex,
        ),
      );

      final pdfBytes = await pdfService.generateReportPdf(
        workspaceName: 'Scale Test Workspace',
        userName: 'Scale Tester',
        range: range,
        records: records,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('PdfExportHandler formats single-day and date-range filenames cleanly',
        () {
      final singleDay = DateTime(2026, 8, 25);
      final fileNameSingle = PdfExportHandler.formatReportFileName(
        prefix: 'WorkPulse_Daily_Report',
        startDate: singleDay,
      );
      expect(fileNameSingle, equals('WorkPulse_Daily_Report_2026-08-25.pdf'));

      final startRange = DateTime(2026, 8, 20);
      final endRange = DateTime(2026, 8, 25);
      final fileNameRange = PdfExportHandler.formatReportFileName(
        prefix: 'WorkPulse_Report',
        startDate: startRange,
        endDate: endRange,
      );
      expect(fileNameRange,
          equals('WorkPulse_Report_2026-08-20_to_2026-08-25.pdf'));
    });

    test('UserInfoService retrieves non-empty user full name or fallback',
        () async {
      UserInfoService.setMockUserName(null);
      final name = await UserInfoService.getCurrentUserFullName();
      expect(name, isNotEmpty);
    });
  });
}
