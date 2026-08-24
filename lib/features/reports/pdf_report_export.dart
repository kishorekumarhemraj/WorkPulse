import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/keyboard/shortcut_labels.dart';
import 'package:workpulse/core/platform/pdf_export_handler.dart';
import 'package:workpulse/core/widgets/app_snack_bar.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

/// Generates a PDF report, saves it, opens it, and reports the outcome.
///
/// The dashboard, the export dialog and the command palette each carried their
/// own copy of this sequence, with three different success messages, three
/// hand-built SnackBars that bypassed the app's `snackBarTheme`, and a
/// "Show in Finder" action hardcoded to macOS. One implementation means the
/// export behaves the same wherever it is started from.
class PdfReportExport {
  /// Where the report ends up. Returned so callers that show their own state
  /// (the export dialog keeps the path on screen) can use it.
  final PdfExportResult result;

  const PdfReportExport(this.result);

  /// Runs the export end to end and shows the result.
  ///
  /// Returns the saved file on success, or null when it failed — in which
  /// case the error has already been surfaced to the user.
  static Future<PdfExportResult?> run(
    BuildContext context,
    WidgetRef ref, {
    required DateRange range,
    required String fileNamePrefix,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final workspace = await ref.read(currentWorkspaceProvider.future);
      final bytes = await ref.read(exportServiceProvider).generatePdf(
            workspaceId: workspace.id,
            range: range,
          );

      final result = await PdfExportHandler.savePdf(
        bytes: bytes,
        fileName: PdfExportHandler.formatReportFileName(
          prefix: fileNamePrefix,
          startDate: range.start,
          endDate: range.end,
        ),
      );

      await PdfExportHandler.openInDefaultApp(result.filePath);

      messenger.showAppSnackBar(
        AppSnackBar.success(
          message: 'Report saved: ${result.fileName}',
          actionLabel: ShortcutLabels.revealActionLabel,
          onAction: () => PdfExportHandler.revealInFileManager(result.filePath),
        ),
      );

      return result;
    } catch (error) {
      messenger.showAppSnackBar(
        AppSnackBar.failure(message: 'PDF export failed: $error'),
      );
      return null;
    }
  }
}
