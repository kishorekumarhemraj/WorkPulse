import 'dart:io';

import 'package:flutter/foundation.dart';
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

    // 2. The user's home Downloads directory, when path_provider could not
    //    resolve one. HOME on macOS/Linux, USERPROFILE on Windows.
    try {
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
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
        const FileSystemException(
            'Could not save PDF to any accessible directory');
  }

  /// Opens the exported file in whatever the OS considers its default
  /// handler — Preview on macOS, the shell association on Windows, the
  /// desktop portal on Linux.
  ///
  /// Used to be macOS-only and silently returned false everywhere else, so on
  /// Windows the export appeared to succeed and then nothing opened.
  static Future<bool> openInDefaultApp(String filePath) {
    if (Platform.isMacOS) {
      return _run('open', [filePath]);
    }
    if (Platform.isWindows) {
      // `start` is a cmd builtin, not an executable, and its first quoted
      // argument is taken as the window title — hence the empty one.
      return _run('cmd', ['/c', 'start', '', filePath]);
    }
    if (Platform.isLinux) {
      return _run('xdg-open', [filePath]);
    }
    return Future.value(false);
  }

  /// Reveals the generated file in the platform's file manager, selected.
  static Future<bool> revealInFileManager(String filePath) {
    if (Platform.isMacOS) {
      return _run('open', ['-R', filePath]);
    }
    if (Platform.isWindows) {
      // explorer.exe returns a non-zero exit code even when it succeeds, so
      // its result is deliberately not treated as failure.
      return _run(
        'explorer',
        ['/select,', _windowsPath(filePath)],
        ignoreExitCode: true,
      );
    }
    if (Platform.isLinux) {
      // No portable "reveal"; opening the containing directory is the closest
      // equivalent that works across desktop environments.
      return _run('xdg-open', [p.dirname(filePath)]);
    }
    return Future.value(false);
  }

  /// Windows Explorer only accepts backslash-separated paths in `/select,`.
  @visibleForTesting
  static String windowsSelectPath(String filePath) => _windowsPath(filePath);

  static String _windowsPath(String filePath) => filePath.replaceAll('/', r'\');

  static Future<bool> _run(
    String executable,
    List<String> arguments, {
    bool ignoreExitCode = false,
  }) async {
    try {
      final result = await Process.run(executable, arguments);
      return ignoreExitCode || result.exitCode == 0;
    } catch (error) {
      debugPrint('[WorkPulse] Could not run $executable: $error');
      return false;
    }
  }

  static bool isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}
