import 'package:flutter/material.dart';
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
import 'package:workpulse/core/widgets/status_badge.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/features/reports/views/session_edit_dialog.dart';
import 'package:workpulse/features/reports/widgets/session_metadata.dart';
import 'package:workpulse/features/tasks/providers/task_sessions_provider.dart';
import 'package:workpulse/features/timesheet/providers/timesheet_provider.dart';
import 'package:workpulse/features/timer/providers/task_duration_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';

/// The detail pane beside the Work Items list.
///
/// Sessions, notes and classification used to be reachable only by expanding
/// a row in place, which pushed the rest of the list down and made comparing
/// two items impossible. On a wide window they now live here instead; the
/// list keeps the inline accordion as its fallback when the window is too
/// narrow for two panes.
class WorkItemInspector extends ConsumerWidget {
  final WorkItem item;
  final Project? project;
  final Category? category;
  final List<Tag> tags;
  final List<Person> people;
  final Map<String, Person> peopleMap;
  final VoidCallback onEdit;
  final VoidCallback? onClose;

  const WorkItemInspector({
    super.key,
    required this.item,
    required this.project,
    required this.category,
    required this.tags,
    required this.people,
    required this.peopleMap,
    required this.onEdit,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final timerState = ref.watch(timerProvider).value;
    final isTrackingThisItem = timerState?.isRunning == true &&
        timerState?.activeWorkItem?.id == item.id;
    final sessionsAsync = ref.watch(workItemSessionRecordsProvider(item.id));
    final codes = ref.watch(timesheetCodeResolverProvider).value ??
        const TimesheetCodeResolver();
    final totalAsync = ref.watch(taskTotalDurationProvider(item.id));

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.xlAll,
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.lg,
              Spacing.sm,
              Spacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: theme.textTheme.titleLarge),
                      const SizedBox(height: Spacing.xs),
                      if (isTrackingThisItem) ...[
                        Container(
                          margin: const EdgeInsets.only(top: Spacing.xs),
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.md,
                            vertical: Spacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: colors.successSubtle,
                            borderRadius: Radii.mdAll,
                            border: Border.all(
                              color: colors.success
                                  .withValues(alpha: Alphas.muted),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: colors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: Spacing.sm),
                              // Flexible so the pill cannot outgrow the pane:
                              // the inspector is two fifths of the window, and
                              // the ticker keeps getting wider — 100:00:00 is
                              // three characters more than 00:00:00.
                              Flexible(
                                child: Text(
                                  'TRACKING NOW • ${TimerService.formatDuration(timerState!.elapsed, includeSeconds: true)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.ticker(
                                    color: colors.success,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Spacing.md),
                              InkWell(
                                onTap: () => ref
                                    .read(timerProvider.notifier)
                                    .stopTimer(),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.stop_circle_outlined,
                                        size: 14,
                                        color: colors.danger,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Stop',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: colors.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        totalAsync.maybeWhen(
                          data: (total) => Text(
                            total == Duration.zero
                                ? 'No time tracked yet'
                                : '${TimerService.formatDuration(total, includeSeconds: false)} tracked in total',
                            style: theme.textTheme.bodySmall,
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!item.isArchived && !isTrackingThisItem)
                  IconButton(
                    icon: Icon(
                      Icons.play_circle_fill,
                      color: colors.success,
                      size: IconSizes.lg,
                    ),
                    tooltip: 'Start tracking',
                    onPressed: () =>
                        ref.read(timerProvider.notifier).startTimer(item),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: IconSizes.md),
                  tooltip: 'Edit work item',
                  onPressed: onEdit,
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: IconSizes.md),
                    tooltip: 'Close inspector',
                    onPressed: onClose,
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                if (item.isArchived) ...[
                  const StatusBadge(
                    label: 'Archived',
                    icon: Icons.archive_outlined,
                    tone: BadgeTone.warning,
                    emphasis: true,
                  ),
                  const SizedBox(height: Spacing.lg),
                ],
                _Section(
                  label: 'Classification',
                  child: Wrap(
                    spacing: Spacing.sm - 2,
                    runSpacing: Spacing.sm - 2,
                    children: [
                      if (project != null)
                        EntityChip(
                          label: project!.name,
                          color: ColorUtils.parseHex(project!.colorHex),
                        ),
                      if (category != null)
                        EntityChip(
                          label: category!.name,
                          icon: IconUtils.getIcon(category!.iconName),
                          color: ColorUtils.parseHex(category!.colorHex),
                        ),
                      for (final tag in tags)
                        EntityChip(
                          label: tag.name,
                          color: ColorUtils.parseHex(tag.colorHex),
                        ),
                      for (final person in people)
                        EntityChip(
                          label: person.name,
                          icon: Icons.person,
                          color: ColorUtils.deterministicColor(person.id),
                        ),
                      if (project == null &&
                          category == null &&
                          tags.isEmpty &&
                          people.isEmpty)
                        Text(
                          'Not classified',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if ((item.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: Spacing.xl),
                  _Section(
                    label: 'Notes',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(Spacing.md),
                      decoration: BoxDecoration(
                        color: colors.surfaceSunken,
                        borderRadius: Radii.mdAll,
                      ),
                      child: Text(
                        item.notes!.trim(),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: Spacing.xl),
                _Section(
                  label: sessionsAsync.maybeWhen(
                    data: (records) => 'Sessions (${records.length})',
                    orElse: () => 'Sessions',
                  ),
                  child: sessionsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: Spacing.lg),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    error: (err, _) => ErrorState(
                      title: 'Could not load sessions',
                      error: err,
                      compact: true,
                      onRetry: () => ref.invalidate(
                        workItemSessionRecordsProvider(item.id),
                      ),
                    ),
                    data: (records) {
                      if (records.isEmpty) {
                        return const EmptyState(
                          icon: Icons.history_toggle_off,
                          title: 'No sessions recorded yet for this item.',
                          compact: true,
                        );
                      }
                      return Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: Radii.mdAll,
                          border: Border.all(color: colors.divider),
                        ),
                        child: ClipRRect(
                          borderRadius: Radii.mdAll,
                          child: Column(
                            children: [
                              for (var i = 0; i < records.length; i++) ...[
                                if (i > 0)
                                  Divider(height: 1, color: colors.divider),
                                _InspectorSessionRow(
                                  record: records[i],
                                  code: codes.resolveFor(
                                    project: records[i].project,
                                    attributeOptionIds:
                                        records[i].attributeOptionIds,
                                  ),
                                  liveElapsed:
                                      (records[i].session.endTime == null &&
                                              isTrackingThisItem)
                                          ? timerState?.elapsed
                                          : null,
                                  onEdited: () {
                                    ref.invalidate(
                                      workItemSessionRecordsProvider(item.id),
                                    );
                                    ref.invalidate(
                                      taskTotalDurationProvider(item.id),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;

  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: colors.textTertiary),
        ),
        const SizedBox(height: Spacing.sm),
        child,
      ],
    );
  }
}

class _InspectorSessionRow extends StatelessWidget {
  final SessionExportRecord record;
  final TimesheetCodeResolution? code;
  final Duration? liveElapsed;
  final VoidCallback onEdited;

  const _InspectorSessionRow({
    required this.record,
    this.code,
    this.liveElapsed,
    required this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d • HH:mm');
    final timeFormat = DateFormat('HH:mm');

    final session = record.session;
    final start = session.startTime.toLocal();
    final end = session.endTime?.toLocal();
    final isRunning = end == null;

    return Hoverable(
      cursor: SystemMouseCursors.click,
      builder: (context, isHovered) {
        return Material(
          color: isHovered ? colors.hover : Colors.transparent,
          child: InkWell(
            hoverColor: Colors.transparent,
            onTap: () async {
              await SessionEditDialog.show(context, record);
              onEdited();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm + 2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      isRunning ? Icons.play_circle : Icons.schedule,
                      size: IconSizes.sm,
                      color: isRunning ? colors.success : colors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRunning
                              ? '${dateFormat.format(start)} – running'
                              : '${dateFormat.format(start)} – ${timeFormat.format(end)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                isRunning ? colors.success : colors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        SessionMetadataChips(
                          record: record,
                          code: code,
                          dense: true,
                          omit: const {SessionMetadataField.project},
                        ),
                        if ((session.notes ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: Spacing.xs),
                          SessionNoteBlock(
                            note: session.notes!.trim(),
                            maxLines: 3,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      TimerService.formatDuration(
                        liveElapsed ?? record.netActiveDuration,
                        includeSeconds: true,
                      ),
                      style: AppTypography.numeric(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isRunning ? colors.success : colors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AnimatedOpacity(
                      opacity: isHovered ? 1 : 0.35,
                      duration: Motion.duration(context, Motion.fast),
                      child: Icon(
                        Icons.edit_outlined,
                        size: IconSizes.sm,
                        color: colors.textTertiary,
                      ),
                    ),
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
