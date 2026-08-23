import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

enum ExportFormat {
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
  ExportFormat _format = ExportFormat.csv;
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
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.getColors(context).surface,
            ),
          ),
          child: child!,
        );
      },
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
    try {
      final workspace = await ref.read(currentWorkspaceProvider.future);
      final domainCustom = _customRange != null
          ? DateRange(start: _customRange!.start, end: _customRange!.end)
          : null;
      final range = _selectedRange.toDateRange(customRange: domainCustom);
      final exportService = ref.read(exportServiceProvider);

      String content;
      if (_format == ExportFormat.csv) {
        content = await exportService.generateCsv(
            workspaceId: workspace.id, range: range);
      } else {
        content = await exportService.generateJson(
            workspaceId: workspace.id, range: range);
      }

      await Clipboard.setData(ClipboardData(text: content));

      if (mounted) {
        setState(() {
          _exportedContent = content;
          _isExporting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_format == ExportFormat.csv ? 'CSV' : 'JSON'} exported and copied to clipboard!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final domainCustomBuild = _customRange != null
        ? DateRange(start: _customRange!.start, end: _customRange!.end)
        : null;
    final range = _selectedRange.toDateRange(customRange: domainCustomBuild);
    final rangeLabel =
        '${DateFormat.yMMMd().format(range.start.toLocal())} – ${DateFormat.yMMMd().format(range.end.toLocal())}';

    return Dialog(
      backgroundColor: AppTheme.getColors(context).surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.getColors(context).divider),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.file_download_outlined,
                        size: 20, color: AppTheme.primaryColor),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Work Data',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.getColors(context).textPrimary),
                        ),
                        Text(
                          'Generate clean reports and structured data backups',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.getColors(context).textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 18, color: AppTheme.getColors(context).textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Date Range Selection
              Text('Date Range',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getColors(context).textSecondary)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.getColors(context).card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.getColors(context).divider),
                ),
                child: Row(
                  children: DashboardTimeRange.values.map((r) {
                    final isSelected = _selectedRange == r;
                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          if (r == DashboardTimeRange.custom) {
                            _pickCustomRange();
                          } else {
                            setState(() => _selectedRange = r);
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            r.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.getColors(context).textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Selected: $rangeLabel',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.getColors(context).textSecondary),
              ),
              SizedBox(height: 20),

              // Format Selection
              Text('Export Format',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getColors(context).textSecondary)),
              SizedBox(height: 8),
              ...ExportFormat.values.map((fmt) {
                final isSelected = _format == fmt;
                return Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () => setState(() => _format = fmt),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : AppTheme.getColors(context).card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.getColors(context).divider,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            fmt == ExportFormat.csv
                                ? Icons.table_chart_outlined
                                : Icons.code,
                            size: 20,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.getColors(context).textSecondary,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fmt.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.getColors(context).textPrimary,
                                  ),
                                ),
                                Text(
                                  fmt.description,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.getColors(context).textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle,
                                size: 18, color: AppTheme.primaryColor),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              SizedBox(height: 20),

              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel',
                        style: TextStyle(color: AppTheme.getColors(context).textSecondary)),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportData,
                    icon: _isExporting
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.copy, size: 16),
                    label: Text(_exportedContent != null
                        ? 'Copied to Clipboard!'
                        : 'Copy to Clipboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
