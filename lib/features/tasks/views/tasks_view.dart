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
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/tasks/views/task_form_dialog.dart';
import 'package:workpulse/features/tasks/widgets/work_item_inspector.dart';
import 'package:workpulse/features/tasks/widgets/work_item_row.dart';
import 'package:workpulse/features/tasks/widgets/work_items_toolbar.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/timer/views/task_switch_dialog.dart';

class TasksView extends ConsumerStatefulWidget {
  const TasksView({super.key});

  @override
  ConsumerState<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends ConsumerState<TasksView> {
  /// The item shown in the inspector, or expanded inline when the window is
  /// too narrow for two panes.
  String? _selectedId;

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
      // Exactly one session may be active, so a switch is confirmed first.
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
    final filter = ref.watch(workItemFilterProvider);
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
        title: 'Work Items',
        subtitle: 'Tracked tasks, issues, and activities across all projects',
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
        toolbar: const WorkItemsToolbar(),
        child: workItemsAsync.when(
          loading: () => const SkeletonList(),
          error: (error, _) => ErrorState(
            title: 'Could not load work items',
            error: error,
            onRetry: () => ref.invalidate(workItemsProvider),
          ),
          data: (workItems) {
            if (workItems.isEmpty) {
              return EmptyState(
                icon: Icons.assignment_outlined,
                title: filter.hasActiveFilters
                    ? 'No work items match your filters'
                    : 'No work items created yet',
                message: filter.hasActiveFilters
                    ? 'Try removing a filter, or widen your search.'
                    : 'Create one to start tracking time against it.',
                action: filter.hasActiveFilters
                    ? OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(workItemFilterProvider.notifier).reset(),
                        icon: const Icon(Icons.clear_all, size: IconSizes.md),
                        label: const Text('Reset Filters'),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => TaskFormDialog.show(context),
                        icon: const Icon(Icons.add, size: IconSizes.md),
                        label: const Text('Create First Task'),
                      ),
              );
            }

            // Drop a selection whose item has been filtered out or deleted.
            final selected =
                workItems.where((item) => item.id == _selectedId).firstOrNull;

            return LayoutBuilder(
              builder: (context, constraints) {
                final showInspector =
                    constraints.maxWidth >= Breakpoints.medium;

                final list = ListView.separated(
                  padding: const EdgeInsets.only(bottom: Spacing.xxl),
                  itemCount: workItems.length,
                  separatorBuilder: (_, __) => SizedBox(
                    height: density == ListDensity.compact
                        ? Spacing.sm - 2
                        : Spacing.sm + 2,
                  ),
                  itemBuilder: (context, index) {
                    final item = workItems[index];
                    final itemTags = item.tagIds
                        .map((id) => tagMap[id])
                        .whereType<Tag>()
                        .toList();
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
                      onEdit: () =>
                          TaskFormDialog.show(context, workItem: item),
                      onArchiveToggle: () => _toggleArchive(item, isActive),
                      onDelete: () => _confirmDelete(item, isActive),
                    );

                    // Narrow windows have no inspector, so selecting a row
                    // expands its detail inline instead — no interaction is
                    // lost, it just moves.
                    if (showInspector || !isSelected) return row;

                    return Column(
                      children: [
                        row,
                        const SizedBox(height: Spacing.sm),
                        SizedBox(
                          height: 320,
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
                );

                if (!showInspector) return list;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: list),
                    const SizedBox(width: Spacing.xl),
                    Expanded(
                      flex: 2,
                      child: selected == null
                          ? const _InspectorPlaceholder()
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
                              onClose: () => setState(() => _selectedId = null),
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
}

class _InspectorPlaceholder extends StatelessWidget {
  const _InspectorPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.4),
        borderRadius: Radii.xlAll,
        border: Border.all(
          color: colors.divider,
          style: BorderStyle.solid,
        ),
      ),
      child: const EmptyState(
        icon: Icons.list_alt,
        title: 'Select a work item',
        message: 'Its sessions, notes and classification appear here without '
            'leaving the list.',
      ),
    );
  }
}
