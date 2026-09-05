import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/core/widgets/entity_chip.dart';
import 'package:workpulse/core/widgets/status_badge.dart';
import 'package:workpulse/domain/models/calendar_date.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/work_item_plan.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
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

  Widget? _buildPlanBadge(BuildContext context, WorkItemPlan plan) {
    final today = CalendarDate.fromLocal(DateTime.now());
    final status = plan.statusOn(today);
    if (status == PlanStatus.unplanned) return null;

    String monthName(int month) {
      const months = [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC'
      ];
      return months[month - 1];
    }

    switch (status) {
      case PlanStatus.overdue:
        final days = plan.daysUntilDue(today)?.abs();
        final label = days != null && days > 1 ? '$days DAYS LATE' : 'OVERDUE';
        return StatusBadge(
          label: label,
          icon: Icons.warning_amber_rounded,
          tone: BadgeTone.danger,
          emphasis: true,
        );
      case PlanStatus.dueToday:
        return const StatusBadge(
          label: 'DUE TODAY',
          icon: Icons.alarm,
          tone: BadgeTone.warning,
          emphasis: true,
        );
      case PlanStatus.startsToday:
        return const StatusBadge(
          label: 'STARTS TODAY',
          icon: Icons.play_arrow_outlined,
          tone: BadgeTone.accent,
          emphasis: true,
        );
      case PlanStatus.scheduled:
        final d = plan.plannedStart!;
        return StatusBadge(
          label: '${d.day} ${monthName(d.month)}',
          icon: Icons.calendar_today_outlined,
          tone: BadgeTone.info,
        );
      case PlanStatus.open:
        final d = plan.due!;
        return StatusBadge(
          label: 'DUE ${d.day} ${monthName(d.month)}',
          icon: Icons.event_outlined,
          tone: BadgeTone.neutral,
        );
      case PlanStatus.completed:
        if (plan.wasLate == true) {
          return const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusBadge(
                label: 'DONE',
                icon: Icons.check_circle_outline,
                tone: BadgeTone.success,
              ),
              SizedBox(width: Spacing.xs),
              StatusBadge(
                label: 'LATE',
                tone: BadgeTone.danger,
              ),
            ],
          );
        }
        return const StatusBadge(
          label: 'DONE',
          icon: Icons.check_circle_outline,
          tone: BadgeTone.success,
        );
      case PlanStatus.unplanned:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final projectColor = ColorUtils.parseHex(project?.colorHex);
    final isCompact = density == ListDensity.compact;
    final planBadge = _buildPlanBadge(context, item.plan);

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
                    if (planBadge != null) ...[
                      const SizedBox(width: Spacing.sm),
                      planBadge,
                    ],
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
            onSelected: (value) async {
              switch (value) {
                case 'edit':
                  onEdit();
                  break;
                case 'complete':
                  await ref
                      .read(workItemsProvider.notifier)
                      .completeWorkItem(item.id);
                  break;
                case 'reopen':
                  await ref
                      .read(workItemsProvider.notifier)
                      .reopenWorkItem(item.id);
                  break;
                case 'set_due_date':
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: item.plan.due?.toLocalDateTime() ??
                        DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    final newPlan = item.plan.copyWith(
                      due: CalendarDate.fromLocal(picked),
                    );
                    await ref
                        .read(workItemsProvider.notifier)
                        .setPlan(item.id, newPlan);
                  }
                  break;
                case 'archive':
                case 'unarchive':
                  onArchiveToggle();
                  break;
                case 'delete':
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: _MenuRow(icon: Icons.edit_outlined, label: 'Edit'),
              ),
              if (item.plan.isComplete)
                const PopupMenuItem(
                  value: 'reopen',
                  child: _MenuRow(
                    icon: Icons.replay_outlined,
                    label: 'Reopen',
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'complete',
                  child: _MenuRow(
                    icon: Icons.check_circle_outline,
                    label: 'Mark complete',
                  ),
                ),
              const PopupMenuItem(
                value: 'set_due_date',
                child: _MenuRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Set due date…',
                ),
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
