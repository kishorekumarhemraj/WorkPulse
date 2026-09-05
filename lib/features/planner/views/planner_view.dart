import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/keyboard/shortcut_labels.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/confirm_dialog.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/core/widgets/page_header.dart';
import 'package:workpulse/core/widgets/skeleton_loader.dart';
import 'package:workpulse/core/widgets/status_badge.dart';
import 'package:workpulse/domain/models/calendar_date.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/shell/models/shell_nav_tab.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/tasks/views/task_form_dialog.dart';
import 'package:workpulse/features/tasks/widgets/work_item_inspector.dart';
import 'package:workpulse/features/tasks/widgets/work_item_row.dart';
import 'package:workpulse/features/tasks/widgets/work_items_toolbar.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/timer/views/task_switch_dialog.dart';

/// The Planner View: organized by urgency, schedule, and deadlines.
class PlannerView extends ConsumerStatefulWidget {
  const PlannerView({super.key});

  @override
  ConsumerState<PlannerView> createState() => _PlannerViewState();
}

class _PlannerViewState extends ConsumerState<PlannerView> {
  String? _selectedId;
  final Set<String> _collapsedSections = {};

  void _toggleSection(String sectionKey) {
    setState(() {
      if (_collapsedSections.contains(sectionKey)) {
        _collapsedSections.remove(sectionKey);
      } else {
        _collapsedSections.add(sectionKey);
      }
    });
  }

  Future<void> _toggleTimer(WorkItem item, bool isActive) async {
    if (isActive) {
      await ref.read(timerProvider.notifier).stopTimer();
      return;
    }

    final currentTimer = ref.read(timerProvider).value;
    final isRunningSomethingElse = currentTimer != null &&
        currentTimer.isRunning &&
        currentTimer.activeWorkItem != null;

    if (isRunningSomethingElse) {
      ref.read(timerProvider.notifier).requestSwitch(item);
      if (!mounted) return;
      await TaskSwitchDialog.show(
        context,
        currentItem: currentTimer.activeWorkItem!,
        currentElapsed: currentTimer.elapsed,
        targetItem: item,
      );
    } else {
      await ref.read(timerProvider.notifier).startTimer(item);
    }

    _revealIfNowTracking(item);
  }

  void _revealIfNowTracking(WorkItem item) {
    if (!mounted) return;

    final timer = ref.read(timerProvider).value;
    final isNowTracking =
        timer != null && timer.isRunning && timer.activeWorkItem?.id == item.id;

    if (!isNowTracking || _selectedId == item.id) return;
    setState(() => _selectedId = item.id);
  }

  Future<void> _confirmDelete(WorkItem item, bool isActive) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete Work Item',
      message: 'Are you sure you want to permanently delete "${item.name}"? '
          'Its recorded sessions will be removed with it.',
    );

    if (!confirmed) return;
    if (isActive) {
      await ref.read(timerProvider.notifier).stopTimer();
    }
    await ref.read(workItemsProvider.notifier).deleteWorkItem(item.id);
    if (mounted && _selectedId == item.id) {
      setState(() => _selectedId = null);
    }
  }

  Future<void> _toggleArchive(WorkItem item, bool isActive) async {
    if (item.isArchived) {
      await ref.read(workItemsProvider.notifier).unarchiveWorkItem(item.id);
      return;
    }
    if (isActive) {
      await ref.read(timerProvider.notifier).stopTimer();
    }
    await ref.read(workItemsProvider.notifier).archiveWorkItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final workItemsAsync = ref.watch(workItemsProvider);
    final density = ref.watch(listDensityProvider);

    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final people = ref.watch(peopleProvider).value ?? const <Person>[];

    final projectMap = {for (final p in projects) p.id: p};
    final categoryMap = {for (final c in categories) c.id: c};
    final tagMap = {for (final t in tags) t.id: t};
    final peopleMap = {for (final p in people) p.id: p};

    return Scaffold(
      backgroundColor: colors.background,
      body: PageScaffold(
        title: 'Planner',
        subtitle:
            'Organise work by schedule, urgency, and upcoming deadlines',
        actions: [
          Tooltip(
            message: 'New work item   ${ShortcutLabels.primary('N')}',
            child: ElevatedButton.icon(
              onPressed: () => TaskFormDialog.show(context),
              icon: const Icon(Icons.add, size: IconSizes.lg),
              label: const Text('New Task'),
            ),
          ),
        ],
        child: workItemsAsync.when(
          loading: () => const SkeletonList(),
          error: (error, _) => ErrorState(
            title: 'Could not load planner',
            error: error,
            onRetry: () => ref.invalidate(workItemsProvider),
          ),
          data: (allWorkItems) {
            final today = CalendarDate.fromLocal(DateTime.now());
            final now = DateTime.now();
            final daysUntilEndOfWeek = 7 - now.weekday;

            // Partition work items into the 7 sections
            final overdue = <WorkItem>[];
            final dueToday = <WorkItem>[];
            final startingToday = <WorkItem>[];
            final thisWeek = <WorkItem>[];
            final later = <WorkItem>[];
            final recentlyCompleted = <WorkItem>[];
            final needsAttention = <WorkItem>[];

            for (final item in allWorkItems) {
              if (item.isArchived) continue;
              final plan = item.plan;

              // Check needs attention
              final isOldOverdue = !plan.isComplete &&
                  plan.due != null &&
                  today.differenceInDays(plan.due!) > 30;
              final isInverted = plan.isInverted;
              if (isOldOverdue || isInverted) {
                needsAttention.add(item);
              }

              if (plan.isComplete) {
                if (plan.completedAt != null &&
                    now.toUtc().difference(plan.completedAt!).inDays <= 7) {
                  recentlyCompleted.add(item);
                }
                continue;
              }

              if (plan.due != null && plan.due! < today) {
                overdue.add(item);
              } else if (plan.due != null && plan.due! == today) {
                dueToday.add(item);
              } else if (plan.plannedStart != null &&
                  plan.plannedStart! == today) {
                startingToday.add(item);
              } else if (plan.due != null &&
                  plan.due! > today &&
                  plan.due!.differenceInDays(today) <= daysUntilEndOfWeek) {
                thisWeek.add(item);
              } else if (plan.due != null || plan.plannedStart != null) {
                later.add(item);
              }
            }

            // Sort each section
            overdue.sort(
                (a, b) => a.plan.due!.compareTo(b.plan.due!)); // oldest first
            dueToday.sort((a, b) => a.name.compareTo(b.name));
            startingToday.sort((a, b) => a.name.compareTo(b.name));
            thisWeek.sort((a, b) => a.plan.due!.compareTo(b.plan.due!));
            later.sort((a, b) {
              final aDate = a.plan.due ?? a.plan.plannedStart!;
              final bDate = b.plan.due ?? b.plan.plannedStart!;
              return aDate.compareTo(bDate);
            });
            recentlyCompleted.sort((a, b) =>
                (b.plan.completedAt ?? DateTime(2000))
                    .compareTo(a.plan.completedAt ?? DateTime(2000)));

            final hasAnyPlanned = overdue.isNotEmpty ||
                dueToday.isNotEmpty ||
                startingToday.isNotEmpty ||
                thisWeek.isNotEmpty ||
                later.isNotEmpty ||
                recentlyCompleted.isNotEmpty ||
                needsAttention.isNotEmpty;

            if (!hasAnyPlanned) {
              return EmptyState(
                icon: Icons.event_note_outlined,
                title: 'Nothing planned',
                message:
                    'Set a due date or planned start on a work item and it will show up here.',
                action: ElevatedButton.icon(
                  onPressed: () => ref
                      .read(activeNavTabProvider.notifier)
                      .setTab(ShellNavTab.tasks),
                  icon: const Icon(Icons.arrow_forward, size: IconSizes.md),
                  label: const Text('Go to Work Items'),
                ),
              );
            }

            // Drop a selection whose item has been deleted.
            final selected = allWorkItems
                .where((item) => item.id == _selectedId)
                .firstOrNull;

            return LayoutBuilder(
              builder: (context, constraints) {
                final showInspector =
                    constraints.maxWidth >= Breakpoints.medium;

                final content = ListView(
                  padding: const EdgeInsets.only(bottom: Spacing.xxl),
                  children: [
                    if (overdue.isNotEmpty)
                      _PlannerSection(
                        title: 'Overdue',
                        count: overdue.length,
                        badgeTone: BadgeTone.danger,
                        isCollapsed: _collapsedSections.contains('overdue'),
                        onToggle: () => _toggleSection('overdue'),
                        children: _buildRowList(
                          overdue,
                          projectMap,
                          categoryMap,
                          tagMap,
                          peopleMap,
                          density,
                          showInspector,
                        ),
                      ),
                    if (dueToday.isNotEmpty)
                      _PlannerSection(
                        title: 'Due Today',
                        count: dueToday.length,
                        badgeTone: BadgeTone.warning,
                        isCollapsed: _collapsedSections.contains('dueToday'),
                        onToggle: () => _toggleSection('dueToday'),
                        children: _buildRowList(
                          dueToday,
                          projectMap,
                          categoryMap,
                          tagMap,
                          peopleMap,
                          density,
                          showInspector,
                        ),
                      ),
                    if (startingToday.isNotEmpty)
                      _PlannerSection(
                        title: 'Starting Today',
                        count: startingToday.length,
                        badgeTone: BadgeTone.accent,
                        isCollapsed:
                            _collapsedSections.contains('startingToday'),
                        onToggle: () => _toggleSection('startingToday'),
                        children: _buildRowList(
                          startingToday,
                          projectMap,
                          categoryMap,
                          tagMap,
                          peopleMap,
                          density,
                          showInspector,
                        ),
                      ),
                    if (thisWeek.isNotEmpty)
                      _PlannerSection(
                        title: 'This Week',
                        count: thisWeek.length,
                        badgeTone: BadgeTone.info,
                        isCollapsed: _collapsedSections.contains('thisWeek'),
                        onToggle: () => _toggleSection('thisWeek'),
                        children: _buildRowList(
                          thisWeek,
                          projectMap,
                          categoryMap,
                          tagMap,
                          peopleMap,
                          density,
                          showInspector,
                        ),
                      ),
                    if (later.isNotEmpty)
                      _PlannerSection(
                        title: 'Later',
                        count: later.length,
                        badgeTone: BadgeTone.neutral,
                        isCollapsed: _collapsedSections.contains('later'),
                        onToggle: () => _toggleSection('later'),
                        children: _buildRowList(
                          later,
                          projectMap,
                          categoryMap,
                          tagMap,
                          peopleMap,
                          density,
                          showInspector,
                        ),
                      ),
                    if (recentlyCompleted.isNotEmpty)
                      _PlannerSection(
                        title: 'Recently Completed',
                        count: recentlyCompleted.length,
                        badgeTone: BadgeTone.success,
                        isCollapsed:
                            _collapsedSections.contains('recentlyCompleted'),
                        onToggle: () => _toggleSection('recentlyCompleted'),
                        children: _buildRowList(
                          recentlyCompleted,
                          projectMap,
                          categoryMap,
                          tagMap,
                          peopleMap,
                          density,
                          showInspector,
                        ),
                      ),
                    if (needsAttention.isNotEmpty)
                      _PlannerSection(
                        title: 'Needs Attention',
                        count: needsAttention.length,
                        badgeTone: BadgeTone.warning,
                        isCollapsed:
                            _collapsedSections.contains('needsAttention'),
                        onToggle: () => _toggleSection('needsAttention'),
                        children: _buildRowList(
                          needsAttention,
                          projectMap,
                          categoryMap,
                          tagMap,
                          peopleMap,
                          density,
                          showInspector,
                        ),
                      ),
                  ],
                );

                if (!showInspector) return content;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: content),
                    const SizedBox(width: Spacing.xl),
                    Expanded(
                      flex: 2,
                      child: selected == null
                          ? const _PlannerInspectorPlaceholder()
                          : WorkItemInspector(
                              item: selected,
                              project: projectMap[selected.projectId],
                              category: categoryMap[selected.categoryId],
                              tags: selected.tagIds
                                  .map((id) => tagMap[id])
                                  .whereType<Tag>()
                                  .toList(),
                              people: selected.peopleIds
                                  .map((id) => peopleMap[id])
                                  .whereType<Person>()
                                  .toList(),
                              peopleMap: peopleMap,
                              onEdit: () => TaskFormDialog.show(
                                context,
                                workItem: selected,
                              ),
                              onClose: () =>
                                  setState(() => _selectedId = null),
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildRowList(
    List<WorkItem> items,
    Map<String, Project> projectMap,
    Map<String, Category> categoryMap,
    Map<String, Tag> tagMap,
    Map<String, Person> peopleMap,
    ListDensity density,
    bool showInspector,
  ) {
    return [
      for (final item in items) ...[
        Builder(
          builder: (context) {
            final itemTags =
                item.tagIds.map((id) => tagMap[id]).whereType<Tag>().toList();
            final itemPeople = item.peopleIds
                .map((id) => peopleMap[id])
                .whereType<Person>()
                .toList();
            final isActive = ref.watch(
              timerProvider.select(
                (s) =>
                    s.value?.isRunning == true &&
                    s.value?.activeWorkItem?.id == item.id,
              ),
            );
            final isSelected = item.id == _selectedId;

            final row = WorkItemRow(
              item: item,
              project: projectMap[item.projectId],
              category: categoryMap[item.categoryId],
              tags: itemTags,
              people: itemPeople,
              isSelected: isSelected,
              density: density,
              onTap: () => setState(
                () => _selectedId = isSelected ? null : item.id,
              ),
              onToggleTimer: () => _toggleTimer(item, isActive),
              onEdit: () => TaskFormDialog.show(context, workItem: item),
              onArchiveToggle: () => _toggleArchive(item, isActive),
              onDelete: () => _confirmDelete(item, isActive),
            );

            if (showInspector || !isSelected) return row;

            return Column(
              children: [
                row,
                const SizedBox(height: Spacing.sm),
                SizedBox(
                  height: 420,
                  child: WorkItemInspector(
                    item: item,
                    project: projectMap[item.projectId],
                    category: categoryMap[item.categoryId],
                    tags: itemTags,
                    people: itemPeople,
                    peopleMap: peopleMap,
                    onEdit: () =>
                        TaskFormDialog.show(context, workItem: item),
                    onClose: () => setState(() => _selectedId = null),
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(
          height: density == ListDensity.compact
              ? Spacing.sm - 2
              : Spacing.sm + 2,
        ),
      ],
    ];
  }
}

class _PlannerSection extends StatelessWidget {
  final String title;
  final int count;
  final BadgeTone badgeTone;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _PlannerSection({
    required this.title,
    required this.count,
    required this.badgeTone,
    required this.isCollapsed,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: Radii.smAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: Spacing.xs,
                horizontal: Spacing.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    isCollapsed
                        ? Icons.chevron_right
                        : Icons.keyboard_arrow_down,
                    size: IconSizes.md,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  StatusBadge(
                    label: count.toString(),
                    tone: badgeTone,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          if (!isCollapsed) ...children,
        ],
      ),
    );
  }
}

class _PlannerInspectorPlaceholder extends StatelessWidget {
  const _PlannerInspectorPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: Alphas.muted),
        borderRadius: Radii.xlAll,
        border: Border.all(
          color: colors.divider,
          style: BorderStyle.solid,
        ),
      ),
      child: const EmptyState(
        icon: Icons.event_note,
        title: 'Select a planned item',
        message: 'Its schedule, status and sessions appear here.',
      ),
    );
  }
}
