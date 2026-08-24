import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
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

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final currentCustom = ref.read(timeNotesCustomRangeProvider);
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
      ref.read(timeNotesCustomRangeProvider.notifier).setCustomRange(picked);
      ref
          .read(timeNotesRangeProvider.notifier)
          .setRange(DashboardTimeRange.custom);
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

        buffer.writeln('- **${note.workItem.name}**$proj ($start - $end • $dur)');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Standup notes copied to clipboard!'),
          ],
        ),
        backgroundColor: context.colors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selectedRange = ref.watch(timeNotesRangeProvider);
    final notesAsync = ref.watch(timeNotesProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: PageScaffold(
        title: 'Time Notes',
        subtitle: 'Review, search, and copy time-based session notes and daily standup summaries',
        actions: [
          AppSegmentedControl<DashboardTimeRange>(
            selected: selectedRange,
            onChanged: (range) {
              if (range == DashboardTimeRange.custom) {
                _pickCustomRange(context, ref);
              } else {
                ref.read(timeNotesRangeProvider.notifier).setRange(range);
              }
            },
            options: const [
              SegmentOption(value: DashboardTimeRange.today, label: 'Today'),
              SegmentOption(value: DashboardTimeRange.thisWeek, label: 'This Week'),
              SegmentOption(value: DashboardTimeRange.thisMonth, label: 'This Month'),
              SegmentOption(value: DashboardTimeRange.custom, label: 'Custom…'),
            ],
          ),
          const SizedBox(width: Spacing.sm),
          notesAsync.maybeWhen(
            data: (groups) => ElevatedButton.icon(
              onPressed: groups.isEmpty
                  ? null
                  : () => _copyStandupNotes(context, groups),
              icon: const Icon(Icons.copy_all, size: IconSizes.sm),
              label: const Text('Copy Notes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
              ),
            ),
            orElse: () => const SizedBox.shrink(),
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
        color: colors.card,
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
            separatorBuilder: (_, __) => Divider(height: 1, color: colors.divider),
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
