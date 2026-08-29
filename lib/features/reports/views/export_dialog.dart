import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/widgets/app_snack_bar.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/widgets/segmented_control.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/features/reports/pdf_report_export.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

enum ExportFormat {
  pdf('PDF (Visual Work Report)',
      'Colorful, executive daily/period report with KPIs, breakdowns & notes'),
  csv('CSV (Spreadsheet / Excel)',
      'Exports tabular data compatible with Excel, Google Sheets, Numbers'),
  json('JSON (Structured Backup)',
      'Exports complete hierarchical data with full metadata');

  final String title;
  final String description;
  const ExportFormat(this.title, this.description);
}

class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ExportDialog(),
    );
  }

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  DashboardTimeRange _selectedRange = DashboardTimeRange.thisWeek;
  DateTimeRange? _customRange;
  ExportFormat _format = ExportFormat.pdf;
  bool _isExporting = false;
  String? _exportedContent;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
    );

    if (picked != null) {
      setState(() {
        _customRange = picked;
        _selectedRange = DashboardTimeRange.custom;
      });
    }
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    final domainCustom = _customRange != null
        ? DateRange(
            start: _customRange!.start.toUtc(),
            end: _customRange!.end.toUtc(),
          )
        : null;
    final range = _selectedRange.toDateRange(customRange: domainCustom);

    try {
      if (_format == ExportFormat.pdf) {
        // Shared with the dashboard and the command palette so a PDF export
        // behaves identically wherever it is started from.
        final result = await PdfReportExport.run(
          context,
          ref,
          range: range,
          fileNamePrefix: 'WorkPulse_Report',
        );
        if (mounted && result != null) {
          setState(() => _exportedContent = result.filePath);
        }
        return;
      }

      final workspace = await ref.read(currentWorkspaceProvider.future);
      final exportService = ref.read(exportServiceProvider);
      final isCsv = _format == ExportFormat.csv;
      final content = isCsv
          ? await exportService.generateCsv(
              workspaceId: workspace.id, range: range)
          : await exportService.generateJson(
              workspaceId: workspace.id, range: range);

      await Clipboard.setData(ClipboardData(text: content));

      if (!mounted) return;
      setState(() => _exportedContent = content);
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar.success(
          message: '${isCsv ? 'CSV' : 'JSON'} exported and copied to clipboard',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar.failure(message: 'Export failed: $error'),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final domainCustomBuild = _customRange != null
        ? DateRange(
            start: _customRange!.start.toUtc(), end: _customRange!.end.toUtc())
        : null;
    final range = _selectedRange.toDateRange(customRange: domainCustomBuild);
    final rangeLabel =
        '${DateFormat.yMMMd().format(range.start.toLocal())} – ${DateFormat.yMMMd().format(range.end.toLocal())}';

    final colors = context.colors;
    final isPdf = _format == ExportFormat.pdf;
    final buttonLabel = isPdf
        ? (_exportedContent != null
            ? 'PDF Exported & Opened!'
            : 'Export & Open PDF')
        : (_exportedContent != null
            ? 'Copied to Clipboard!'
            : 'Copy to Clipboard');

    return AppDialog(
      title: 'Export Work Data',
      subtitle: 'Generate clean reports and structured data backups',
      icon: Icons.file_download_outlined,
      width: DialogWidth.medium,
      onSubmit: _isExporting ? null : _exportData,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isExporting ? null : _exportData,
          icon: _isExporting
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onAccent,
                  ),
                )
              : Icon(
                  _exportedContent != null
                      ? Icons.check
                      : (isPdf ? Icons.picture_as_pdf_outlined : Icons.copy),
                  size: IconSizes.md,
                ),
          label: Text(buttonLabel),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DialogField(
            label: 'Date Range',
            helperText: 'Selected: $rangeLabel',
            child: AppSegmentedControl<DashboardTimeRange>(
              fillWidth: true,
              selected: _selectedRange,
              onChanged: (range) {
                if (range == DashboardTimeRange.custom) {
                  _pickCustomRange();
                } else {
                  setState(() => _selectedRange = range);
                }
              },
              options: [
                for (final r in DashboardTimeRange.values)
                  SegmentOption(value: r, label: r.label),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          DialogField(
            label: 'Export Format',
            child: Column(
              children: [
                for (final fmt in ExportFormat.values) ...[
                  if (fmt != ExportFormat.values.first)
                    const SizedBox(height: Spacing.sm),
                  _FormatOption(
                    format: fmt,
                    isSelected: _format == fmt,
                    onTap: () => setState(() => _format = fmt),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One selectable export format.
class _FormatOption extends StatelessWidget {
  final ExportFormat format;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatOption({
    required this.format,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final foreground = isSelected ? colors.accent : colors.textSecondary;

    return Semantics(
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: '${format.title}. ${format.description}',
      child: Material(
        color: isSelected ? colors.accentSubtle : colors.card,
        borderRadius: Radii.mdAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.mdAll,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: Radii.mdAll,
              border: Border.all(
                color: isSelected ? colors.accent : colors.divider,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                Icon(
                  format == ExportFormat.pdf
                      ? Icons.picture_as_pdf_outlined
                      : (format == ExportFormat.csv
                          ? Icons.table_chart_outlined
                          : Icons.code),
                  size: IconSizes.lg,
                  color: foreground,
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        format.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color:
                              isSelected ? colors.accent : colors.textPrimary,
                        ),
                      ),
                      Text(
                        format.description,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // Selection is marked with a tick as well as colour, so it is
                // not communicated by colour alone.
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: IconSizes.lg,
                    color: colors.accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
