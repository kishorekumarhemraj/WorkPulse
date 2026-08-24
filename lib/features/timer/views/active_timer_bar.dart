import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/keyboard/shortcut_labels.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/core/widgets/entity_chip.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/quick_capture/views/quick_capture_dialog.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';

/// The persistent header shown while a session is running.
///
/// This is the app's most-glanced-at surface, so the elapsed time is rendered
/// in the tabular monospace face — with proportional digits the numbers
/// visibly shift every second.
class ActiveTimerBar extends ConsumerWidget {
  const ActiveTimerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final timerState = ref.watch(timerProvider).value;
    final projects = ref.watch(projectsProvider).value ?? [];
    final categories = ref.watch(categoriesProvider).value ?? [];
    final workItems = ref.watch(workItemsProvider).value ?? [];

    if (timerState == null ||
        !timerState.isRunning ||
        timerState.activeWorkItem == null) {
      return const SizedBox.shrink();
    }

    final activeItem = workItems
            .where((w) => w.id == timerState.activeWorkItem!.id)
            .firstOrNull ??
        timerState.activeWorkItem!;
    final project =
        projects.where((p) => p.id == activeItem.projectId).firstOrNull;
    final projectColor = ColorUtils.parseHex(project?.colorHex);

    final activeCategoryId =
        timerState.activeSession?.categoryId ?? activeItem.categoryId;
    final activeCategory =
        categories.where((c) => c.id == activeCategoryId).firstOrNull;

    final formattedTime =
        TimerService.formatDuration(timerState.elapsed, includeSeconds: true);

    return Container(
      height: ControlSizes.timerBar,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showProject = constraints.maxWidth >= 880;
          final showTrackingLabel = constraints.maxWidth >= 780;
          final showCategory = constraints.maxWidth >= 680;
          final showSwitch = constraints.maxWidth >= 620;

          return Row(
            children: [
              // Project colour spine — ties the bar to the work being tracked.
              Container(width: 3, color: projectColor),
              const SizedBox(width: Spacing.lg),

              const _LiveDot(),
              const SizedBox(width: Spacing.sm + 2),
              if (showTrackingLabel) ...[
                Text(
                  'TRACKING',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: colors.success),
                ),
                const SizedBox(width: Spacing.md),
              ],

              if (showProject && project != null) ...[
                EntityChip(label: project.name, color: projectColor),
                const SizedBox(width: Spacing.sm + 2),
              ],

              if (showCategory && categories.isNotEmpty) ...[
                PopupMenuButton<String>(
                  tooltip: 'Change session category',
                  onSelected: (catId) {
                    ref
                        .read(timerProvider.notifier)
                        .updateActiveSessionCategory(catId);
                  },
                  itemBuilder: (context) => [
                    for (final cat in categories)
                      PopupMenuItem(
                        value: cat.id,
                        child: Row(
                          children: [
                            Icon(
                              IconUtils.getIcon(cat.iconName),
                              size: 16,
                              color: cat.id == activeCategoryId
                                  ? colors.accent
                                  : colors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontWeight: cat.id == activeCategoryId
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: cat.id == activeCategoryId
                                    ? colors.accent
                                    : colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceSunken,
                      borderRadius: Radii.smAll,
                      border: Border.all(color: colors.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          IconUtils.getIcon(
                              activeCategory?.iconName ?? 'folder'),
                          size: 13,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          activeCategory?.name ?? 'Category',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm + 2),
              ],

              Expanded(
                child: Text(
                  activeItem.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Spacing.md),

              // Live duration
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: colors.successSubtle,
                  borderRadius: Radii.mdAll,
                  border:
                      Border.all(color: colors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: IconSizes.sm,
                      color: colors.success,
                    ),
                    const SizedBox(width: Spacing.sm - 2),
                    Text(
                      formattedTime,
                      style: AppTypography.ticker(color: colors.success),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.md),

              if (showSwitch) ...[
                OutlinedButton.icon(
                  onPressed: () => QuickCaptureDialog.show(context),
                  icon: const Icon(Icons.swap_horiz, size: IconSizes.md),
                  label: const Text('Switch'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, ControlSizes.toolbar),
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
              ],

              Tooltip(
                message: 'Stop tracking   ${ShortcutLabels.primary('.')}',
                child: ElevatedButton.icon(
                  onPressed: () => ref.read(timerProvider.notifier).stopTimer(),
                  icon: const Icon(Icons.stop, size: IconSizes.md),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.dangerSubtle,
                    foregroundColor: colors.danger,
                    minimumSize: const Size(0, ControlSizes.toolbar),
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: Radii.mdAll,
                      side: BorderSide(
                        color: colors.danger.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.lg),
            ],
          );
        },
      ),
    );
  }
}

/// The "session is live" marker.
///
/// Deliberately static rather than pulsing: the elapsed time beside it is
/// already incrementing every second, so an infinitely repeating animation
/// would add no information while repainting forever (this bar is on screen
/// all day) and would leave `pumpAndSettle` with no frame to settle on in
/// every test that renders a running timer.
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: colors.success,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.success.withValues(alpha: 0.45),
            blurRadius: 7,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
