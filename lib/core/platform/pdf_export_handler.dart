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

  /// Saves the given PDF bytes to the user's Downloads, Documents, or Temporary directory with robust fallback.
  static Future<PdfExportResult> savePdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final candidateDirs = <Directory>[];

    // 1. Try Downloads directory via path_provider
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        candidateDirs.add(downloads);
      }
    } catch (_) {}

    // 2. Direct user home Downloads directory on macOS if accessible
    try {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        candidateDirs.add(Directory(p.join(home, 'Downloads')));
      }
    } catch (_) {}

    // 3. Application Documents Directory
    try {
      final docs = await getApplicationDocumentsDirectory();
      candidateDirs.add(docs);
    } catch (_) {}

    // 4. Temporary Directory
    try {
      final temp = await getTemporaryDirectory();
      candidateDirs.add(temp);
    } catch (_) {}

    Object? lastError;

    for (final dir in candidateDirs) {
      try {
        if (!dir.existsSync()) {
          await dir.create(recursive: true);
        }
        final filePath = p.join(dir.path, fileName);
        final file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);

        return PdfExportResult(
          filePath: filePath,
          fileName: fileName,
          byteCount: bytes.length,
        );
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    throw lastError ??
        const FileSystemException('Could not save PDF to any accessible directory');
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
