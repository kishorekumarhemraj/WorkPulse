import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/keyboard/shortcut_labels.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/confirm_dialog.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/core/widgets/page_header.dart';
import 'package:workpulse/core/widgets/skeleton_loader.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/reports/views/export_dialog.dart';
import 'package:workpulse/features/reports/views/session_edit_dialog.dart';
import 'package:workpulse/features/reports/widgets/reports_range_controls.dart';
import 'package:workpulse/features/reports/widgets/session_day_group.dart';
import 'package:workpulse/features/timesheet/providers/timesheet_provider.dart';

class SessionHistoryView extends ConsumerWidget {
  const SessionHistoryView({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
    String taskName,
  ) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete Session',
      message: 'Are you sure you want to delete this session for "$taskName"? '
          'This action cannot be undone.',
    );

    if (confirmed) {
      await ref.read(sessionEditorControllerProvider).deleteSession(sessionId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selectedRange = ref.watch(reportsTimeRangeProvider);
    final selectedDate = ref.watch(reportsDateProvider);
    final sessionsAsync = ref.watch(sessionHistoryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: PageScaffold(
        title: 'Time Log',
        subtitle: formatReportsRangeSubtitle(selectedRange, selectedDate),
        actions: [
          const ReportsRangePicker(),
          const ReportsDateStepper(),
          Tooltip(
            message: 'Export data   ${ShortcutLabels.primary('E')}',
            child: ElevatedButton.icon(
              onPressed: () => ExportDialog.show(context),
              icon: const Icon(
                Icons.file_download_outlined,
                size: IconSizes.md,
              ),
              label: const Text('Export Data'),
            ),
          ),
          IconButton(
            onPressed: () => ref.invalidate(sessionHistoryProvider),
            icon: const Icon(Icons.refresh, size: IconSizes.md),
            tooltip: 'Refresh session log',
            style: IconButton.styleFrom(
              minimumSize:
                  const Size(ControlSizes.standard, ControlSizes.standard),
              maximumSize:
                  const Size(ControlSizes.standard, ControlSizes.standard),
              padding: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
            ),
          ),
        ],
        child: sessionsAsync.when(
          loading: () => const SkeletonList(itemCount: 4, itemHeight: 140),
          error: (err, stack) => ErrorState(
            title: 'Could not load sessions',
            error: err,
            onRetry: () => ref.invalidate(sessionHistoryProvider),
          ),
          data: (records) {
            if (records.isEmpty) {
              return const EmptyState(
                icon: Icons.history_toggle_off,
                title: 'No sessions recorded in this period',
                message: 'Start a timer on a work item, or navigate dates to '
                    'see earlier sessions.',
              );
            }

            final codes = ref
                    .watch(timesheetCodeResolverProvider)
                    .value ??
                const TimesheetCodeResolver();

            // Group by local calendar day, newest first. The provider
            // already returns records ordered by start time, so each day's
            // list keeps that order.
            final grouped = <DateTime, List<SessionExportRecord>>{};
            for (final record in records) {
              final local = record.session.startTime.toLocal();
              final day = DateTime(local.year, local.month, local.day);
              grouped.putIfAbsent(day, () => []).add(record);
            }
            final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

            final rangeTotal = records.fold<Duration>(
              Duration.zero,
              (sum, record) => sum + record.netActiveDuration,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RangeSummary(
                  sessionCount: records.length,
                  dayCount: days.length,
                  total: rangeTotal,
                ),
                const SizedBox(height: Spacing.lg),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: Spacing.xxl),
                    itemCount: days.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Spacing.xl),
                    itemBuilder: (context, index) {
                      final day = days[index];
                      return SessionDayGroup(
                        day: day,
                        records: grouped[day]!,
                        codes: codes,
                        onEdit: (record) =>
                            SessionEditDialog.show(context, record),
                        onDelete: (record) => _confirmDelete(
                          context,
                          ref,
                          record.session.id,
                          record.workItem.name,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A one-line total for everything currently in range, so the number the
/// screen exists to report is visible without scrolling.
class _RangeSummary extends StatelessWidget {
  final int sessionCount;
  final int dayCount;
  final Duration total;

  const _RangeSummary({
    required this.sessionCount,
    required this.dayCount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: Radii.mdAll,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Icon(Icons.summarize_outlined,
              size: IconSizes.md, color: colors.accent),
          const SizedBox(width: Spacing.sm),
          Text(
            'Range total',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(width: Spacing.sm),
          Text(
            TimerService.formatDuration(total, includeSeconds: false),
            style: AppTypography.numeric(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            '$sessionCount session${sessionCount == 1 ? '' : 's'} '
            'across $dayCount day${dayCount == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
