import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/features/reports/widgets/session_row.dart';

/// One day of sessions, under a header carrying the day's total.
///
/// The log was previously a flat list of equally-weighted rows, each
/// repeating its own date. Grouping by day removes that repetition and
/// answers the question the screen is usually opened for — "how much did I
/// log that day?" — without the user adding rows up by eye.
class SessionDayGroup extends StatelessWidget {
  final DateTime day;
  final List<SessionExportRecord> records;
  final TimesheetCodeResolver codes;
  final void Function(SessionExportRecord record) onEdit;
  final void Function(SessionExportRecord record) onDelete;

  const SessionDayGroup({
    super.key,
    required this.day,
    required this.records,
    this.codes = const TimesheetCodeResolver(),
    required this.onEdit,
    required this.onDelete,
  });

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(day.year, day.month, day.day);
    final difference = today.difference(target).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(day);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final total = records.fold<Duration>(
      Duration.zero,
      (sum, record) => sum + record.netActiveDuration,
    );
    final isToday = _dayLabel(day) == 'Today';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.xs,
            0,
            Spacing.xs,
            Spacing.sm,
          ),
          child: Row(
            children: [
              Text(
                _dayLabel(day),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isToday ? colors.accent : colors.textPrimary,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                DateFormat('d MMM yyyy').format(day),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textTertiary),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(child: Divider(height: 1, color: colors.divider)),
              const SizedBox(width: Spacing.md),
              Text(
                '${records.length} session${records.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textTertiary),
              ),
              const SizedBox(width: Spacing.md),
              Text(
                TimerService.formatDuration(total, includeSeconds: false),
                style: AppTypography.numeric(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.xlAll,
            border: Border.all(color: colors.divider),
          ),
          child: ClipRRect(
            borderRadius: Radii.xlAll,
            child: Column(
              children: [
                for (var i = 0; i < records.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.divider),
                  SessionRow(
                    record: records[i],
                    codes: codes,
                    isFirst: i == 0,
                    isLast: i == records.length - 1,
                    onEdit: () => onEdit(records[i]),
                    onDelete: () => onDelete(records[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
