import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/reports/views/export_dialog.dart';
import 'package:workpulse/features/reports/views/session_edit_dialog.dart';

class SessionHistoryView extends ConsumerWidget {
  const SessionHistoryView({super.key});

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final currentCustom = ref.read(reportsCustomRangeProvider);
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: currentCustom ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
    );

    if (picked != null) {
      ref.read(reportsCustomRangeProvider.notifier).setCustomRange(picked);
      ref
          .read(reportsTimeRangeProvider.notifier)
          .setRange(DashboardTimeRange.custom);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      String sessionId, String taskName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getColors(context).surface,
        title: Text('Delete Session',
            style: TextStyle(color: AppTheme.getColors(context).textPrimary)),
        content: Text(
            'Are you sure you want to delete this session for "$taskName"? This action cannot be undone.',
            style: TextStyle(color: AppTheme.getColors(context).textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: TextStyle(
                      color: AppTheme.getColors(context).textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(sessionEditorControllerProvider).deleteSession(sessionId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(reportsTimeRangeProvider);
    final sessionsAsync = ref.watch(sessionHistoryProvider);
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('EEE, MMM d');

    return Scaffold(
      backgroundColor: AppTheme.getColors(context).background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time Log & History',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.getColors(context).textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View and edit historical time tracking sessions',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.getColors(context).textSecondary),
                      ),
                    ],
                  ),
                ),

                // Range Selector Filter Pills
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.getColors(context).surface,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppTheme.getColors(context).divider),
                  ),
                  child: Row(
                    children: DashboardTimeRange.values.map((r) {
                      final isSelected = selectedRange == r;
                      return Material(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          onTap: () {
                            if (r == DashboardTimeRange.custom) {
                              _pickCustomRange(context, ref);
                            } else {
                              ref
                                  .read(reportsTimeRangeProvider.notifier)
                                  .setRange(r);
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
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
                const SizedBox(width: 12),

                // Export Button
                ElevatedButton.icon(
                  onPressed: () => ExportDialog.show(context),
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text('Export Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),

                // Refresh Button
                IconButton(
                  onPressed: () => ref.invalidate(sessionHistoryProvider),
                  icon: Icon(Icons.refresh,
                      size: 18,
                      color: AppTheme.getColors(context).textSecondary),
                  tooltip: 'Refresh session log',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sessions List
            Expanded(
              child: sessionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                    child: Text('Error loading sessions: $err',
                        style: const TextStyle(color: AppTheme.accentRed))),
                data: (records) {
                  if (records.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_toggle_off,
                              size: 48,
                              color: AppTheme.getColors(context)
                                  .textSecondary
                                  .withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'No sessions recorded in this period',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color:
                                    AppTheme.getColors(context).textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final s = record.session;
                      final projectColor =
                          ColorUtils.parseHex(record.project?.colorHex);
                      final startStr = timeFormat.format(s.startTime.toLocal());
                      final endStr = s.endTime != null
                          ? timeFormat.format(s.endTime!.toLocal())
                          : 'Running';
                      final dateStr = dateFormat.format(s.startTime.toLocal());
                      final netDurationStr = TimerService.formatDuration(
                          record.netActiveDuration,
                          includeSeconds: true);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.getColors(context).surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.getColors(context).divider),
                        ),
                        child: Row(
                          children: [
                            // Date & Time Column
                            SizedBox(
                              width: 140,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dateStr,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.getColors(context)
                                              .textPrimary)),
                                  const SizedBox(height: 2),
                                  Text('$startStr – $endStr',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.getColors(context)
                                              .textSecondary)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Project & Category Badges
                            if (record.project != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: projectColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                            color: projectColor,
                                            shape: BoxShape.circle)),
                                    const SizedBox(width: 5),
                                    Text(record.project!.name,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: projectColor)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],

                            if (record.category != null) ...[
                              Icon(IconUtils.getIcon(record.category!.iconName),
                                  size: 14,
                                  color: AppTheme.getColors(context)
                                      .textSecondary),
                              const SizedBox(width: 4),
                              Text(record.category!.name,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.getColors(context)
                                          .textSecondary)),
                              const SizedBox(width: 12),
                            ],

                            // Work Item Name
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.workItem.name,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.getColors(context)
                                            .textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (record.session.notes != null &&
                                      record.session.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      record.session.notes!,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: AppTheme.getColors(context)
                                              .textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Idle Deduction Tag (if any)
                            if (record.idleDuration.inSeconds > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentOrange
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '-${TimerService.formatDuration(record.idleDuration, includeSeconds: true)} idle',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accentOrange),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],

                            // Net Active Duration Chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.getColors(context).card,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppTheme.getColors(context).divider),
                              ),
                              child: Text(
                                netDurationStr,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentGreen),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Edit Button
                            IconButton(
                              icon: Icon(Icons.edit_outlined,
                                  size: 16,
                                  color: AppTheme.getColors(context)
                                      .textSecondary),
                              tooltip: 'Edit session',
                              onPressed: () =>
                                  SessionEditDialog.show(context, record),
                            ),

                            // Delete Button
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: AppTheme.accentRed),
                              tooltip: 'Delete session',
                              onPressed: () => _confirmDelete(
                                  context, ref, s.id, record.workItem.name),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
