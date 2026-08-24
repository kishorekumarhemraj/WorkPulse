import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
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
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/notes/models/time_note_entry.dart';
import 'package:workpulse/features/notes/providers/time_notes_provider.dart';
import 'package:workpulse/features/reports/views/session_edit_dialog.dart';

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
    Map<DateTime, List<TimeNoteEntry>> dayGroups,
  ) {
    if (dayGroups.isEmpty) return;

    final buffer = StringBuffer();
    final dayFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('HH:mm');

    for (final entry in dayGroups.entries) {
      buffer.writeln('### ${dayFormat.format(entry.key)}');
      buffer.writeln();

      for (final note in entry.value) {
        final start = timeFormat.format(note.startTime.toLocal());
        final end = note.endTime != null
            ? timeFormat.format(note.endTime!.toLocal())
            : 'running';
        final dur = TimerService.formatDuration(note.duration, compact: true);
        final proj = note.project != null ? ' [${note.project!.name}]' : '';

        buffer
            .writeln('- **${note.workItem.name}**$proj ($start - $end • $dur)');
        final noteLines = note.note.split('\n');
        for (final line in noteLines) {
          if (line.trim().isNotEmpty) {
            buffer.writeln('  • ${line.trim()}');
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

    final now = DateTime.now();

    return Scaffold(
      backgroundColor: colors.surface,
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
            data: (groups) => ElevatedButton.icon(
              onPressed: groups.isEmpty
                  ? null
                  : () => _copyStandupNotes(context, groups),
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
                loading: () => const SkeletonList(itemCount: 6),
                error: (error, _) => ErrorState(
                  title: 'Could not load time notes',
                  error: error,
                  onRetry: () => ref.invalidate(timeNotesProvider),
                ),
                data: (dayGroups) {
                  if (dayGroups.isEmpty) {
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

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: Spacing.xxl),
                    itemCount: dayGroups.length,
                    itemBuilder: (context, index) {
                      final dayKey = dayGroups.keys.elementAt(index);
                      final dayNotes = dayGroups[dayKey]!;
                      return _DayNotesGroup(
                        day: dayKey,
                        notes: dayNotes,
                        onNoteEdited: () => ref.invalidate(timeNotesProvider),
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

class _DayNotesGroup extends StatelessWidget {
  final DateTime day;
  final List<TimeNoteEntry> notes;
  final VoidCallback onNoteEdited;

  const _DayNotesGroup({
    required this.day,
    required this.notes,
    required this.onNoteEdited,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final isToday = DateUtils.isSameDay(day, DateTime.now());
    final isYesterday = DateUtils.isSameDay(
      day,
      DateTime.now().subtract(const Duration(days: 1)),
    );

    final dayLabel = isToday
        ? 'Today • ${DateFormat('EEEE, MMM d').format(day)}'
        : (isYesterday
            ? 'Yesterday • ${DateFormat('EEEE, MMM d').format(day)}'
            : DateFormat('EEEE, MMMM d, yyyy').format(day));

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.xlAll,
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg,
              vertical: Spacing.md,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
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
                const Spacer(),
                Text(
                  '${notes.length} ${notes.length == 1 ? 'note' : 'notes'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // Notes items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: notes.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: colors.divider),
            itemBuilder: (context, i) {
              final note = notes[i];
              return _TimeNoteCard(
                entry: note,
                onEdited: onNoteEdited,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TimeNoteCard extends StatelessWidget {
  final TimeNoteEntry entry;
  final VoidCallback onEdited;

  const _TimeNoteCard({
    required this.entry,
    required this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');

    final start = timeFormat.format(entry.startTime.toLocal());
    final end = entry.endTime != null
        ? timeFormat.format(entry.endTime!.toLocal())
        : 'Running';
    final isRunning = entry.endTime == null;

    final projectColor = ColorUtils.parseHex(entry.project?.colorHex);

    return Hoverable(
      cursor: SystemMouseCursors.click,
      builder: (context, isHovered) {
        return Material(
          color: isHovered ? colors.hover : Colors.transparent,
          child: InkWell(
            hoverColor: Colors.transparent,
            onTap: () async {
              final record = SessionExportRecord(
                session: entry.session,
                workItem: entry.workItem,
                project: entry.project,
                category: entry.category,
                people: entry.people,
                tags: entry.tags,
                grossDuration: entry.duration,
                idleDuration: Duration.zero,
                netActiveDuration: entry.duration,
              );
              await SessionEditDialog.show(context, record);
              onEdited();
            },
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Time Badge + Task Name + Chips
                  Row(
                    children: [
                      // Time badge
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
                                ? colors.success.withValues(alpha: 0.4)
                                : colors.divider,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isRunning ? Icons.play_arrow : Icons.access_time,
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
                      ),
                      const SizedBox(width: Spacing.md),

                      // Task Name
                      Expanded(
                        child: Text(
                          entry.workItem.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Chips
                      if (entry.project != null) ...[
                        EntityChip(
                          label: entry.project!.name,
                          color: projectColor,
                        ),
                        const SizedBox(width: Spacing.xs),
                      ],
                      if (entry.category != null) ...[
                        EntityChip(
                          label: entry.category!.name,
                          icon: IconUtils.getIcon(entry.category!.iconName),
                        ),
                        const SizedBox(width: Spacing.xs),
                      ],
                      for (final tag in entry.tags) ...[
                        EntityChip(
                          label: '#${tag.name}',
                          color: ColorUtils.parseHex(tag.colorHex),
                        ),
                        const SizedBox(width: Spacing.xs),
                      ],
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
                  const SizedBox(height: Spacing.md),

                  // Note callout container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: colors.surfaceSunken,
                      borderRadius: Radii.mdAll,
                      border: Border.all(color: colors.divider),
                    ),
                    child: Text(
                      entry.note,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),

                  // People tagged
                  if (entry.people.isNotEmpty) ...[
                    const SizedBox(height: Spacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 13,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        for (final person in entry.people) ...[
                          EntityChip(
                            label: person.name,
                            plain: true,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
