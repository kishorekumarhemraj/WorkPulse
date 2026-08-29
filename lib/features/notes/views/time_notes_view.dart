import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/classification_style.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/core/widgets/app_snack_bar.dart';
import 'package:workpulse/core/widgets/date_stepper.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/core/widgets/entity_chip.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/core/widgets/hoverable.dart';
import 'package:workpulse/core/widgets/page_header.dart';
import 'package:workpulse/core/widgets/segmented_control.dart';
import 'package:workpulse/core/widgets/skeleton_loader.dart';
import 'package:workpulse/core/widgets/status_badge.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/time_note_model.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/features/notes/providers/time_notes_provider.dart';
import 'package:workpulse/features/reports/views/session_edit_dialog.dart';
import 'package:workpulse/features/reports/widgets/session_metadata.dart';
import 'package:workpulse/features/timesheet/providers/timesheet_provider.dart';

class TimeNotesView extends ConsumerWidget {
  const TimeNotesView({super.key});

  String _formatSubtitle(
    DashboardTimeRange range,
    DateTime selectedDate,
  ) {
    final now = DateTime.now();
    switch (range) {
      case DashboardTimeRange.today:
        return 'Today · ${DateFormat.yMMMMEEEEd().format(selectedDate)}';
      case DashboardTimeRange.thisWeek:
        final dateRange = DashboardTimeRange.thisWeek.toDateRange();
        final startStr = DateFormat.yMMMd().format(dateRange.start.toLocal());
        final endStr = DateFormat.yMMMd().format(dateRange.end.toLocal());
        return 'This Week · $startStr – $endStr';
      case DashboardTimeRange.thisMonth:
        final dateRange = DashboardTimeRange.thisMonth.toDateRange();
        final monthStr = DateFormat.yMMMM().format(dateRange.start.toLocal());
        return 'This Month · $monthStr';
      case DashboardTimeRange.custom:
        final isToday = selectedDate.year == now.year &&
            selectedDate.month == now.month &&
            selectedDate.day == now.day;
        if (isToday) {
          return 'Today · ${DateFormat.yMMMMEEEEd().format(selectedDate)}';
        }
        return DateFormat.yMMMMEEEEd().format(selectedDate);
    }
  }

  String _formatDateButtonLabel(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final isTomorrow = date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;

    final formatted = DateFormat.yMMMd().format(date);
    if (isToday) return 'Today, $formatted';
    if (isYesterday) return 'Yesterday, $formatted';
    if (isTomorrow) return 'Tomorrow, $formatted';
    return '${DateFormat.E().format(date)}, $formatted';
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final currentDate = ref.read(timeNotesDateProvider);
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      ref.read(timeNotesDateProvider.notifier).setDate(picked);
      final isToday = picked.year == now.year &&
          picked.month == now.month &&
          picked.day == now.day;
      ref.read(timeNotesRangeProvider.notifier).setRange(
            isToday ? DashboardTimeRange.today : DashboardTimeRange.custom,
          );
    }
  }

  void _copyStandupNotes(
    BuildContext context,
    TimeNotesReport report,
  ) {
    if (report.isEmpty) return;

    final buffer = StringBuffer();
    final dayFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('HH:mm');

    for (final dayGroup in report.dayGroups) {
      buffer.writeln('### ${dayFormat.format(dayGroup.day)}');
      buffer.writeln();

      for (final taskGroup in dayGroup.taskGroups) {
        final proj =
            taskGroup.project != null ? ' [${taskGroup.project!.name}]' : '';
        final dur =
            TimerService.formatDuration(taskGroup.totalDuration, compact: true);
        buffer.writeln(
            '- **${taskGroup.workItem.name}**$proj (${taskGroup.sessionCount} sessions • $dur)');

        for (final entry in taskGroup.entries) {
          final start =
              timeFormat.format(entry.record.session.startTime.toLocal());
          final end = entry.record.session.endTime != null
              ? timeFormat.format(entry.record.session.endTime!.toLocal())
              : 'running';
          final noteLines = entry.note.split('\n');
          for (var i = 0; i < noteLines.length; i++) {
            final line = noteLines[i].trim();
            if (line.isEmpty) continue;
            if (i == 0) {
              buffer.writeln('  • ($start – $end) $line');
            } else {
              buffer.writeln('    $line');
            }
          }
        }
      }
      buffer.writeln();
    }

    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    ScaffoldMessenger.of(context).showAppSnackBar(
      const AppSnackBar.success(
        message: 'Standup notes copied to clipboard',
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selectedRange = ref.watch(timeNotesRangeProvider);
    final selectedDate = ref.watch(timeNotesDateProvider);
    final notesAsync = ref.watch(timeNotesProvider);
    final codes = ref.watch(timesheetCodeResolverProvider).value ??
        const TimesheetCodeResolver();

    final now = DateTime.now();

    return Scaffold(
      backgroundColor: colors.background,
      body: PageScaffold(
        title: 'Time Notes',
        subtitle: _formatSubtitle(selectedRange, selectedDate),
        actions: [
          // Time Range Segmented Control (Today, This Week, This Month, Date)
          AppSegmentedControl<DashboardTimeRange>(
            selected: selectedRange,
            onChanged: (range) {
              ref.read(timeNotesRangeProvider.notifier).setRange(range);
              if (range == DashboardTimeRange.today) {
                ref.read(timeNotesDateProvider.notifier).goToToday();
              } else if (range == DashboardTimeRange.custom) {
                _pickDate(context, ref);
              }
            },
            options: const [
              SegmentOption(value: DashboardTimeRange.today, label: 'Today'),
              SegmentOption(
                  value: DashboardTimeRange.thisWeek, label: 'This Week'),
              SegmentOption(
                  value: DashboardTimeRange.thisMonth, label: 'This Month'),
              SegmentOption(value: DashboardTimeRange.custom, label: 'Date'),
            ],
          ),
          // Date Navigation Bar (Previous day, Current Date, Next day)
          AppDateStepper(
            label: _formatDateButtonLabel(selectedDate),
            onPrevious: () {
              ref.read(timeNotesDateProvider.notifier).previousDay();
              final newDate = ref.read(timeNotesDateProvider);
              final isNewToday = newDate.year == now.year &&
                  newDate.month == now.month &&
                  newDate.day == now.day;
              ref.read(timeNotesRangeProvider.notifier).setRange(
                    isNewToday
                        ? DashboardTimeRange.today
                        : DashboardTimeRange.custom,
                  );
            },
            onNext: () {
              ref.read(timeNotesDateProvider.notifier).nextDay();
              final newDate = ref.read(timeNotesDateProvider);
              final isNewToday = newDate.year == now.year &&
                  newDate.month == now.month &&
                  newDate.day == now.day;
              ref.read(timeNotesRangeProvider.notifier).setRange(
                    isNewToday
                        ? DashboardTimeRange.today
                        : DashboardTimeRange.custom,
                  );
            },
            onPickDate: () => _pickDate(context, ref),
          ),
          notesAsync.maybeWhen(
            data: (report) => ElevatedButton.icon(
              onPressed: report.isEmpty
                  ? null
                  : () => _copyStandupNotes(context, report),
              icon: const Icon(Icons.copy_all, size: IconSizes.md),
              label: const Text('Copy Notes'),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            onPressed: () => ref.invalidate(timeNotesProvider),
            icon: const Icon(Icons.refresh, size: IconSizes.md),
            tooltip: 'Refresh notes',
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
        child: Column(
          children: [
            // Search box
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.lg),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search notes, work items, projects, or people…',
                  prefixIcon: const Icon(Icons.search, size: IconSizes.md),
                  suffixIcon: ref.watch(timeNotesSearchProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: IconSizes.sm),
                          onPressed: () => ref
                              .read(timeNotesSearchProvider.notifier)
                              .setQuery(''),
                        )
                      : null,
                ),
                onChanged: (q) =>
                    ref.read(timeNotesSearchProvider.notifier).setQuery(q),
              ),
            ),

            // Content
            Expanded(
              child: notesAsync.when(
                loading: () =>
                    const SkeletonList(itemCount: 4, itemHeight: 140),
                error: (error, _) => ErrorState(
                  title: 'Could not load time notes',
                  error: error,
                  onRetry: () => ref.invalidate(timeNotesProvider),
                ),
                data: (report) {
                  if (report.isEmpty) {
                    final isFiltered =
                        ref.watch(timeNotesSearchProvider).isNotEmpty;
                    return EmptyState(
                      icon: Icons.speaker_notes_off_outlined,
                      title: isFiltered
                          ? 'No notes match your search'
                          : 'No notes logged for this period',
                      message: isFiltered
                          ? 'Try changing your search terms or clearing the filter.'
                          : 'Add closing notes when switching tasks or editing sessions to record your daily progress.',
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NotesSummaryCard(report: report),
                      const SizedBox(height: Spacing.lg),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: Spacing.xxl),
                          itemCount: report.dayGroups.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: Spacing.xl),
                          itemBuilder: (context, index) {
                            final dayGroup = report.dayGroups[index];
                            if (report.isSingleDay) {
                              return Column(
                                children: [
                                  for (var i = 0;
                                      i < dayGroup.taskGroups.length;
                                      i++) ...[
                                    if (i > 0)
                                      const SizedBox(height: Spacing.md),
                                    _TaskNoteCard(
                                      group: dayGroup.taskGroups[i],
                                      codes: codes,
                                      onEdited: () =>
                                          ref.invalidate(timeNotesProvider),
                                    ),
                                  ],
                                ],
                              );
                            }
                            return _DayNotesSection(
                              dayGroup: dayGroup,
                              codes: codes,
                              onEdited: () => ref.invalidate(timeNotesProvider),
                            );
                          },
                        ),
                      ),
                    ],
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

class _NotesSummaryCard extends StatelessWidget {
  final TimeNotesReport report;

  const _NotesSummaryCard({required this.report});

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
        color: colors.surface,
        borderRadius: Radii.lgAll,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          _SummaryMetric(
            label: 'Notes',
            value: '${report.totalNotes}',
          ),
          const SizedBox(width: Spacing.xl),
          _SummaryMetric(
            label: 'Tasks',
            value: '${report.totalTasks}',
          ),
          const SizedBox(width: Spacing.xl),
          _SummaryMetric(
            label: 'Tracked Time',
            value: TimerService.formatDuration(report.totalDuration,
                includeSeconds: false),
          ),
          const Spacer(),
          if (report.unnotedSessions > 0)
            Text(
              '${report.unnotedSessions} unnoted session${report.unnotedSessions == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.numeric(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DayNotesSection extends StatelessWidget {
  final NotesDayGroup dayGroup;
  final TimesheetCodeResolver codes;
  final VoidCallback onEdited;

  const _DayNotesSection({
    required this.dayGroup,
    required this.codes,
    required this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final isToday = DateUtils.isSameDay(dayGroup.day, DateTime.now());
    final isYesterday = DateUtils.isSameDay(
      dayGroup.day,
      DateTime.now().subtract(const Duration(days: 1)),
    );

    final dayLabel = isToday
        ? 'Today • ${DateFormat('EEEE, MMM d').format(dayGroup.day)}'
        : (isYesterday
            ? 'Yesterday • ${DateFormat('EEEE, MMM d').format(dayGroup.day)}'
            : DateFormat('EEEE, MMMM d, yyyy').format(dayGroup.day));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: Spacing.xs,
            right: Spacing.xs,
            bottom: Spacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: IconSizes.sm,
                color: isToday ? colors.accent : colors.textSecondary,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                dayLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                  color: isToday ? colors.accent : colors.textPrimary,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(child: Divider(height: 1, color: colors.divider)),
              const SizedBox(width: Spacing.md),
              Text(
                '${dayGroup.noteCount} note${dayGroup.noteCount == 1 ? '' : 's'} • ${TimerService.formatDuration(dayGroup.totalDuration, includeSeconds: false)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < dayGroup.taskGroups.length; i++) ...[
          if (i > 0) const SizedBox(height: Spacing.md),
          _TaskNoteCard(
            group: dayGroup.taskGroups[i],
            codes: codes,
            onEdited: onEdited,
          ),
        ],
      ],
    );
  }
}

class _TaskNoteCard extends StatelessWidget {
  final TaskNoteGroup group;
  final TimesheetCodeResolver codes;
  final VoidCallback onEdited;

  const _TaskNoteCard({
    required this.group,
    required this.codes,
    required this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final projectColor = ColorUtils.parseHex(group.project?.colorHex);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.xlAll,
        border: Border.all(color: colors.divider),
      ),
      child: ClipRRect(
        borderRadius: Radii.xlAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Card Header: Promoted metadata
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.md,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                border: Border(bottom: BorderSide(color: colors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.workItem.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        Wrap(
                          spacing: Spacing.xs,
                          runSpacing: Spacing.xxs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (group.project != null)
                              EntityChip(
                                label: group.project!.name,
                                color: projectColor,
                              ),
                            if (group.category != null)
                              EntityChip(
                                label: group.category!.name,
                                icon:
                                    IconUtils.getIcon(group.category!.iconName),
                                color: ColorUtils.parseHex(
                                    group.category!.colorHex),
                              ),
                            if (group.classification.isClassified)
                              StatusBadge(
                                label: group.classification.label,
                                icon: group.classification.icon,
                                color: group.classification.colorOf(context),
                                outlined: true,
                              ),
                            if (group.timesheetCode?.code != null &&
                                group.timesheetCode!.code!.isNotEmpty)
                              EntityChip(
                                icon: Icons.receipt_long_outlined,
                                label: group.timesheetCode!.code!,
                                color: group.timesheetCode!.needsAttention
                                    ? colors.warning
                                    : null,
                                plain: true,
                              ),
                            for (final tag in group.tags)
                              EntityChip(
                                label: '#${tag.name}',
                                color: ColorUtils.parseHex(tag.colorHex),
                              ),
                            for (final person in group.people)
                              EntityChip(
                                label: person.name,
                                icon: Icons.person,
                                color: ColorUtils.deterministicColor(person.id),
                                plain: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        TimerService.formatDuration(
                          group.totalDuration,
                          includeSeconds: false,
                        ),
                        style: AppTypography.numeric(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${group.sessionCount} session${group.sessionCount == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Entries
            for (var i = 0; i < group.entries.length; i++) ...[
              if (i > 0) Divider(height: 1, color: colors.divider),
              _TaskNoteEntryRow(
                entry: group.entries[i],
                promotedFields: group.promotedFields,
                codes: codes,
                onEdited: onEdited,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskNoteEntryRow extends StatelessWidget {
  final TimeNoteEntry entry;
  final Set<SessionMetadataField> promotedFields;
  final TimesheetCodeResolver codes;
  final VoidCallback onEdited;

  const _TaskNoteEntryRow({
    required this.entry,
    required this.promotedFields,
    required this.codes,
    required this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final timeFormat = DateFormat('HH:mm');

    final start = timeFormat.format(entry.record.session.startTime.toLocal());
    final end = entry.record.session.endTime != null
        ? timeFormat.format(entry.record.session.endTime!.toLocal())
        : 'Running';
    final isRunning = entry.record.session.endTime == null;

    final codeResolution = codes.resolveFor(
      project: entry.record.project,
      attributeOptionIds: entry.record.attributeOptionIds,
    );

    return Hoverable(
      cursor: SystemMouseCursors.click,
      builder: (context, isHovered) {
        return Material(
          color: isHovered ? colors.hover : Colors.transparent,
          child: InkWell(
            hoverColor: Colors.transparent,
            onTap: () async {
              await SessionEditDialog.show(context, entry.record);
              onEdited();
            },
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (entry.source == TimeNoteSource.session)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sm,
                            vertical: Spacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: isRunning
                                ? colors.successSubtle
                                : colors.surfaceSunken,
                            borderRadius: Radii.smAll,
                            border: Border.all(
                              color: isRunning
                                  ? colors.success
                                      .withValues(alpha: Alphas.muted)
                                  : colors.divider,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isRunning
                                    ? Icons.play_arrow
                                    : Icons.access_time,
                                size: 12,
                                color: isRunning
                                    ? colors.success
                                    : colors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$start – $end • ${TimerService.formatDuration(entry.duration, compact: true)}',
                                style: AppTypography.numeric(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isRunning
                                      ? colors.success
                                      : colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const StatusBadge(
                          label: 'Task note',
                          icon: Icons.notes,
                          tone: BadgeTone.neutral,
                        ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: SessionMetadataChips(
                          record: entry.record,
                          code: codeResolution,
                          omit: promotedFields,
                          dense: true,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      AnimatedOpacity(
                        opacity: isHovered ? 1.0 : 0.35,
                        duration: Motion.duration(context, Motion.fast),
                        child: Icon(
                          Icons.edit_outlined,
                          size: IconSizes.sm,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),
                  SessionNoteBlock(
                    note: entry.note,
                    callout: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
