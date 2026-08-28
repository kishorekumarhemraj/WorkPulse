import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/core/widgets/entity_chip.dart';
import 'package:workpulse/core/widgets/status_badge.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/tasks/widgets/work_items_toolbar.dart';
import 'package:workpulse/features/timer/providers/task_duration_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';

/// A work item in the list.
///
/// Classification chips are hidden in compact density, where the list is
/// being used to scan names rather than to compare metadata.
class WorkItemRow extends ConsumerWidget {
  final WorkItem item;
  final Project? project;
  final Category? category;
  final List<Tag> tags;
  final List<Person> people;
  final bool isSelected;
  final ListDensity density;
  final VoidCallback onTap;
  final VoidCallback onToggleTimer;
  final VoidCallback onEdit;
  final VoidCallback onArchiveToggle;
  final VoidCallback onDelete;

  const WorkItemRow({
    super.key,
    required this.item,
    required this.project,
    required this.category,
    required this.tags,
    required this.people,
    required this.isSelected,
    required this.density,
    required this.onTap,
    required this.onToggleTimer,
    required this.onEdit,
    required this.onArchiveToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final projectColor = ColorUtils.parseHex(project?.colorHex);
    final isCompact = density == ListDensity.compact;

    final isItemActive = ref.watch(
      timerProvider.select(
        (s) =>
            s.value?.isRunning == true &&
            s.value?.activeWorkItem?.id == item.id,
      ),
    );

    return AppCard(
      radius: Radii.lg,
      isSelected: isSelected,
      emphasisColor: isItemActive ? colors.successFill : null,
      leadingStripe: isItemActive ? colors.successFill : projectColor,
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: Spacing.md + 2,
        vertical: isCompact ? Spacing.sm + 2 : Spacing.md + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: item.isArchived
                              ? colors.textTertiary
                              : colors.textPrimary,
                          decoration: item.isArchived
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (isItemActive) ...[
                      const SizedBox(width: Spacing.sm),
                      const StatusBadge(
                        label: 'Tracking',
                        icon: Icons.timer,
                        tone: BadgeTone.success,
                        emphasis: true,
                        outlined: true,
                      ),
                    ],
                    if (item.isArchived) ...[
                      const SizedBox(width: Spacing.sm),
                      const StatusBadge(
                        label: 'Archived',
                        icon: Icons.archive_outlined,
                        tone: BadgeTone.warning,
                        emphasis: true,
                      ),
                    ],
                  ],
                ),
                if (!isCompact) ...[
                  if ((item.notes ?? '').isNotEmpty) ...[
                    const SizedBox(height: Spacing.xs),
                    Text(
                      item.notes!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: Spacing.sm),
                  Wrap(
                    spacing: Spacing.sm - 2,
                    runSpacing: Spacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (project != null)
                        EntityChip(label: project!.name, color: projectColor),
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
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          _DurationBadge(workItemId: item.id, isItemActive: isItemActive),
          const SizedBox(width: Spacing.sm),
          if (!item.isArchived)
            IconButton(
              icon: Icon(
                isItemActive ? Icons.stop_circle : Icons.play_circle_fill,
                size: 26,
                color: isItemActive ? colors.danger : colors.accent,
              ),
              tooltip: isItemActive ? 'Stop timer' : 'Start timer',
              onPressed: onToggleTimer,
            ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              size: IconSizes.lg,
              color: colors.textSecondary,
            ),
            tooltip: 'More actions',
            onSelected: (value) => switch (value) {
              'edit' => onEdit(),
              'archive' || 'unarchive' => onArchiveToggle(),
              'delete' => onDelete(),
              _ => null,
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: _MenuRow(icon: Icons.edit_outlined, label: 'Edit'),
              ),
              if (item.isArchived)
                const PopupMenuItem(
                  value: 'unarchive',
                  child: _MenuRow(
                    icon: Icons.unarchive_outlined,
                    label: 'Unarchive',
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'archive',
                  child: _MenuRow(
                    icon: Icons.archive_outlined,
                    label: 'Archive',
                  ),
                ),
              PopupMenuItem(
                value: 'delete',
                child: _MenuRow(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: colors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MenuRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final effective = color ?? context.colors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: IconSizes.md, color: effective),
        const SizedBox(width: Spacing.sm),
        Text(label, style: TextStyle(color: effective)),
      ],
    );
  }
}

/// Total time on the item, or the live elapsed time while it is tracking.
class _DurationBadge extends ConsumerWidget {
  final String workItemId;
  final bool isItemActive;

  const _DurationBadge({required this.workItemId, required this.isItemActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    if (isItemActive) {
      final elapsed = ref.watch(
          timerProvider.select((s) => s.value?.elapsed ?? Duration.zero));
      return MetricChip(
        value: TimerService.formatDuration(elapsed, includeSeconds: true),
        icon: Icons.schedule,
        color: colors.success,
        emphasis: true,
      );
    }

    final totalAsync = ref.watch(taskTotalDurationProvider(workItemId));
    return totalAsync.maybeWhen(
      data: (duration) {
        if (duration == Duration.zero) return const SizedBox.shrink();
        return MetricChip(
          value: TimerService.formatDuration(duration, compact: true),
          icon: Icons.schedule,
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
