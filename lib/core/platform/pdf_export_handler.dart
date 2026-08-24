import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PdfExportResult {
  final String filePath;
  final String fileName;
  final int byteCount;

  const PdfExportResult({
    required this.filePath,
    required this.fileName,
    required this.byteCount,
  });
}

class PdfExportHandler {
  /// Generates a standardized, clean filename for PDF reports.
  static String formatReportFileName({
    required String prefix,
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final startStr = dateFormat.format(startDate.toLocal());
    if (endDate != null && !isSameDay(startDate, endDate)) {
      final endStr = dateFormat.format(endDate.toLocal());
      return '${prefix}_${startStr}_to_$endStr.pdf';
    }
    return '${prefix}_$startStr.pdf';
  }

  /// Saves the given PDF bytes to the user's Downloads or Documents directory.
  static Future<PdfExportResult> savePdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    Directory? targetDir;
    try {
      targetDir = await getDownloadsDirectory();
    } catch (_) {
      // Fallback
    }

    targetDir ??= await getApplicationDocumentsDirectory();

    final filePath = p.join(targetDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    return PdfExportResult(
      filePath: filePath,
      fileName: fileName,
      byteCount: bytes.length,
    );
  }

  /// Opens the PDF file using macOS's default handler (Preview.app).
  static Future<bool> openPdfInPreview(String filePath) async {
    try {
      if (!Platform.isMacOS) {
        return false;
      }
      final res = await Process.run('open', [filePath]);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Reveals the generated file in macOS Finder.
  static Future<bool> revealInFinder(String filePath) async {
    try {
      if (!Platform.isMacOS) {
        return false;
      }
      final res = await Process.run('open', ['-R', filePath]);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static bool isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}
