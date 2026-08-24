import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/platform/pdf_export_handler.dart';

void main() {
  group('PdfExportHandler.formatReportFileName', () {
    test('uses a single date for a same-day range', () {
      final name = PdfExportHandler.formatReportFileName(
        prefix: 'WorkPulse_Daily_Report',
        startDate: DateTime(2026, 3, 14, 9),
        endDate: DateTime(2026, 3, 14, 17),
      );
      expect(name, 'WorkPulse_Daily_Report_2026-03-14.pdf');
    });

    test('spans both dates for a multi-day range', () {
      final name = PdfExportHandler.formatReportFileName(
        prefix: 'WorkPulse_Report',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31),
      );
      expect(name, 'WorkPulse_Report_2026-03-01_to_2026-03-31.pdf');
    });

    test('omits the range when there is no end date', () {
      final name = PdfExportHandler.formatReportFileName(
        prefix: 'WorkPulse_Report',
        startDate: DateTime(2026, 3, 1),
      );
      expect(name, 'WorkPulse_Report_2026-03-01.pdf');
    });
  });

  group('PdfExportHandler.isSameDay', () {
    test('compares local calendar days, not instants', () {
      expect(
        PdfExportHandler.isSameDay(
          DateTime(2026, 3, 14, 0, 1),
          DateTime(2026, 3, 14, 23, 59),
        ),
        isTrue,
      );
      expect(
        PdfExportHandler.isSameDay(
          DateTime(2026, 3, 14, 23, 59),
          DateTime(2026, 3, 15, 0, 1),
        ),
        isFalse,
      );
    });
  });

  // Explorer's /select, switch rejects forward slashes, and `path` on Windows
  // will happily hand back a mixed-separator path.
  group('PdfExportHandler.windowsSelectPath', () {
    test('normalises separators to backslashes', () {
      expect(
        PdfExportHandler.windowsSelectPath('C:/Users/kkh/Downloads/report.pdf'),
        r'C:\Users\kkh\Downloads\report.pdf',
      );
    });

    test('leaves an already-backslashed path alone', () {
      expect(
        PdfExportHandler.windowsSelectPath(r'C:\Users\kkh\report.pdf'),
        r'C:\Users\kkh\report.pdf',
      );
    });
  });
}
