import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/reports/views/session_edit_dialog.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tasks/providers/task_sessions_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/tasks/views/task_form_dialog.dart';
import 'package:workpulse/features/timer/providers/task_duration_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/timer/views/task_switch_dialog.dart';

class TasksView extends ConsumerWidget {
  const TasksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workItemsAsync = ref.watch(workItemsProvider);
    final filter = ref.watch(workItemFilterProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final peopleAsync = ref.watch(peopleProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Work Items',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.getColors(context).textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tracked tasks, issues, and activities across all projects',
                        style: TextStyle(fontSize: 13, color: AppTheme.getColors(context).textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => TaskFormDialog.show(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter and Search Toolbar
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Search field
                SizedBox(
                  width: 240,
                  height: 36,
                  child: TextField(
                    onChanged: (val) => ref.read(workItemFilterProvider.notifier).setSearchQuery(val),
                    style: TextStyle(fontSize: 13, color: AppTheme.getColors(context).textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      prefixIcon: Icon(Icons.search, size: 16, color: AppTheme.getColors(context).textSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),

                // Project Filter Dropdown
                projectsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (projects) {
                    return Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.getColors(context).surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: filter.projectId != null ? AppTheme.primaryColor : AppTheme.getColors(context).divider,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: projects.any((p) => p.id == filter.projectId) ? filter.projectId : null,
                          hint: Text('All Projects', style: TextStyle(fontSize: 13, color: AppTheme.getColors(context).textSecondary)),
                          icon: Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.getColors(context).textSecondary),
                          dropdownColor: AppTheme.getColors(context).surface,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Projects', style: TextStyle(fontSize: 13)),
                            ),
                            ...projects.map((p) => DropdownMenuItem<String?>(
                                  value: p.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(color: ColorUtils.parseHex(p.colorHex), shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(p.name, style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                )),
                          ],
                          onChanged: (val) => ref.read(workItemFilterProvider.notifier).setProject(val),
                        ),
                      ),
                    );
                  },
                ),

                // Category Filter Dropdown
                categoriesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (categories) {
                    return Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.getColors(context).surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: filter.categoryId != null ? AppTheme.primaryColor : AppTheme.getColors(context).divider,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: categories.any((c) => c.id == filter.categoryId) ? filter.categoryId : null,
                          hint: Text('All Categories', style: TextStyle(fontSize: 13, color: AppTheme.getColors(context).textSecondary)),
                          icon: Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.getColors(context).textSecondary),
                          dropdownColor: AppTheme.getColors(context).surface,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Categories', style: TextStyle(fontSize: 13)),
                            ),
                            ...categories.map((c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(IconUtils.getIcon(c.iconName), size: 14, color: AppTheme.primaryColor),
                                      const SizedBox(width: 6),
                                      Text(c.name, style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                )),
                          ],
                          onChanged: (val) => ref.read(workItemFilterProvider.notifier).setCategory(val),
                        ),
                      ),
                    );
                  },
                ),

                // Tag Filter Dropdown
                tagsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (tags) {
                    if (tags.isEmpty) return const SizedBox.shrink();
                    return Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.getColors(context).surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: filter.tagId != null ? AppTheme.primaryColor : AppTheme.getColors(context).divider,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: tags.any((t) => t.id == filter.tagId) ? filter.tagId : null,
                          hint: Text('All Tags', style: TextStyle(fontSize: 13, color: AppTheme.getColors(context).textSecondary)),
                          icon: Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.getColors(context).textSecondary),
                          dropdownColor: AppTheme.getColors(context).surface,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Tags', style: TextStyle(fontSize: 13)),
                            ),
                            ...tags.map((t) => DropdownMenuItem<String?>(
                                  value: t.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(color: ColorUtils.parseHex(t.colorHex), shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(t.name, style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                )),
                          ],
                          onChanged: (val) => ref.read(workItemFilterProvider.notifier).setTag(val),
                        ),
                      ),
                    );
                  },
                ),

                // Archived Toggle Filter
                FilterChip(
                  label: const Text('Include Archived'),
                  selected: filter.includeArchived,
                  onSelected: (_) => ref.read(workItemFilterProvider.notifier).toggleIncludeArchived(),
                  backgroundColor: AppTheme.getColors(context).surface,
                  selectedColor: AppTheme.accentOrange.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: filter.includeArchived ? AppTheme.accentOrange : AppTheme.getColors(context).textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: filter.includeArchived ? AppTheme.accentOrange : AppTheme.getColors(context).divider,
                    ),
                  ),
                ),

                // Clear Filters button
                if (filter.hasActiveFilters)
                  TextButton.icon(
                    onPressed: () => ref.read(workItemFilterProvider.notifier).reset(),
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text('Clear Filters', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.accentRed),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Work Items List
            Expanded(
              child: workItemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Error loading tasks: $error', style: const TextStyle(color: AppTheme.accentRed)),
                ),
                data: (workItems) {
                  if (workItems.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined, size: 48, color: AppTheme.getColors(context).textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            filter.hasActiveFilters ? 'No tasks match current filters' : 'No tasks created yet',
                            style: TextStyle(fontSize: 16, color: AppTheme.getColors(context).textSecondary),
                          ),
                          const SizedBox(height: 12),
                          if (filter.hasActiveFilters)
                            OutlinedButton(
                              onPressed: () => ref.read(workItemFilterProvider.notifier).reset(),
                              child: const Text('Reset Filters'),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () => TaskFormDialog.show(context),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Create First Task'),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                            ),
                        ],
                      ),
                    );
                  }

                  final projects = projectsAsync.value ?? [];
                  final categories = categoriesAsync.value ?? [];
                  final tags = tagsAsync.value ?? [];
                  final people = peopleAsync.value ?? [];

                  final projectMap = {for (final p in projects) p.id: p};
                  final categoryMap = {for (final c in categories) c.id: c};
                  final tagMap = {for (final t in tags) t.id: t};
                  final peopleMap = {for (final p in people) p.id: p};

                  return ListView.separated(
                    itemCount: workItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = workItems[index];
                      final project = projectMap[item.projectId];
                      final category = categoryMap[item.categoryId];
                      final itemTags = item.tagIds.map((id) => tagMap[id]).whereType<Tag>().toList();
                      final itemPeople = item.peopleIds.map((id) => peopleMap[id]).whereType<Person>().toList();

                      return _WorkItemCard(
                        item: item,
                        project: project,
                        category: category,
                        tags: itemTags,
                        people: itemPeople,
                        peopleMap: peopleMap,
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

class _WorkItemCard extends ConsumerStatefulWidget {
  final WorkItem item;
  final Project? project;
  final Category? category;
  final List<Tag> tags;
  final List<Person> people;
  final Map<String, Person> peopleMap;

  const _WorkItemCard({
    required this.item,
    required this.project,
    required this.category,
    required this.tags,
    required this.people,
    required this.peopleMap,
  });

  @override
  ConsumerState<_WorkItemCard> createState() => _WorkItemCardState();
}

class _WorkItemCardState extends ConsumerState<_WorkItemCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final project = widget.project;
    final category = widget.category;
    final tags = widget.tags;
    final people = widget.people;

    final projectColor = ColorUtils.parseHex(project?.colorHex);
    final sessionsAsync = ref.watch(sessionsForWorkItemProvider(item.id));
    final isItemActive = ref.watch(
      timerProvider.select(
        (s) =>
            s.value?.isRunning == true &&
            s.value?.activeWorkItem?.id == item.id,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getColors(context).surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isItemActive
              ? AppTheme.accentGreen.withValues(alpha: 0.8)
              : (item.isArchived ? AppTheme.getColors(context).divider.withValues(alpha: 0.5) : AppTheme.getColors(context).divider),
          width: isItemActive ? 1.5 : 1,
        ),
        boxShadow: isItemActive
            ? [
                BoxShadow(
                  color: AppTheme.accentGreen.withValues(alpha: 0.12),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project color vertical strip
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: isItemActive ? AppTheme.accentGreen : projectColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),

              // Main Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: item.isArchived ? AppTheme.getColors(context).textSecondary : AppTheme.getColors(context).textPrimary,
                              decoration: item.isArchived ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (isItemActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer, size: 11, color: AppTheme.accentGreen),
                                SizedBox(width: 3),
                                Text(
                                  'TRACKING',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
                                ),
                              ],
                            ),
                          ),
                        if (item.isArchived)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentOrange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ARCHIVED',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentOrange),
                            ),
                          ),
                      ],
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.notes!,
                        style: TextStyle(fontSize: 12, color: AppTheme.getColors(context).textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),

                    // Meta badges: Project, Category, Tags, People, Total Duration, Sessions
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Project Badge
                        if (project != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: projectColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: projectColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.folder_outlined, size: 12, color: projectColor),
                                const SizedBox(width: 4),
                                Text(
                                  project.name,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: projectColor),
                                ),
                              ],
                            ),
                          ),

                        // Category Badge
                        if (category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.getColors(context).card,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(IconUtils.getIcon(category.iconName), size: 12, color: AppTheme.getColors(context).textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  category.name,
                                  style: TextStyle(fontSize: 11, color: AppTheme.getColors(context).textSecondary),
                                ),
                              ],
                            ),
                          ),

                        // Tags
                        ...tags.map((t) {
                          final tagColor = ColorUtils.parseHex(t.colorHex);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tagColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 6, height: 6, decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text(
                                  t.name,
                                  style: TextStyle(fontSize: 11, color: tagColor, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        }),

                        // People
                        ...people.map((p) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.getColors(context).card,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person, size: 11, color: AppTheme.getColors(context).textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  p.name,
                                  style: TextStyle(fontSize: 11, color: AppTheme.getColors(context).textSecondary),
                                ),
                              ],
                            ),
                          );
                        }),

                        // Total Duration Badge
                        _TaskDurationBadge(
                          workItemId: item.id,
                          isItemActive: isItemActive,
                        ),

                        // Interactive Sessions Badge / Toggle Button
                        InkWell(
                          onTap: () => setState(() => _isExpanded = !_isExpanded),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _isExpanded
                                  ? AppTheme.primaryColor.withValues(alpha: 0.18)
                                  : AppTheme.getColors(context).card,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _isExpanded
                                    ? AppTheme.primaryColor.withValues(alpha: 0.5)
                                    : AppTheme.getColors(context).divider,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isExpanded ? Icons.expand_less : Icons.history,
                                  size: 11,
                                  color: _isExpanded ? AppTheme.primaryColor : AppTheme.getColors(context).textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  sessionsAsync.maybeWhen(
                                    data: (sessions) => 'Sessions (${sessions.length})',
                                    orElse: () => 'Sessions',
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: _isExpanded ? FontWeight.w600 : FontWeight.normal,
                                    color: _isExpanded ? AppTheme.primaryColor : AppTheme.getColors(context).textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Play / Stop Action Button
              if (!item.isArchived) ...[
                IconButton(
                  icon: Icon(
                    isItemActive ? Icons.stop_circle : Icons.play_circle_fill,
                    size: 26,
                    color: isItemActive ? AppTheme.accentRed : AppTheme.primaryColor,
                  ),
                  tooltip: isItemActive ? 'Stop timer' : 'Start timer',
                  onPressed: () async {
                    if (isItemActive) {
                      await ref.read(timerProvider.notifier).stopTimer();
                    } else {
                      final currentTimer = ref.read(timerProvider).value;
                      final running = currentTimer != null && currentTimer.isRunning && currentTimer.activeWorkItem != null;
                      if (running) {
                        ref.read(timerProvider.notifier).requestSwitch(item);
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
                  },
                ),
                const SizedBox(width: 4),
              ],

              // Actions Popup Menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: AppTheme.getColors(context).textSecondary),
                color: AppTheme.getColors(context).surface,
                onSelected: (value) async {
                  if (value == 'edit') {
                    await TaskFormDialog.show(context, workItem: item);
                  } else if (value == 'archive') {
                    if (isItemActive) {
                      await ref.read(timerProvider.notifier).stopTimer();
                    }
                    await ref.read(workItemsProvider.notifier).archiveWorkItem(item.id);
                  } else if (value == 'unarchive') {
                    await ref.read(workItemsProvider.notifier).unarchiveWorkItem(item.id);
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.getColors(context).surface,
                        title: Text('Delete Task', style: TextStyle(color: AppTheme.getColors(context).textPrimary)),
                        content: Text('Are you sure you want to permanently delete task "${item.name}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, foregroundColor: Colors.white),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      if (isItemActive) {
                        await ref.read(timerProvider.notifier).stopTimer();
                      }
                      await ref.read(workItemsProvider.notifier).deleteWorkItem(item.id);
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: AppTheme.getColors(context).textPrimary),
                        const SizedBox(width: 8),
                        const Text('Edit'),
                      ],
                    ),
                  ),
                  if (item.isArchived)
                    PopupMenuItem(
                      value: 'unarchive',
                      child: Row(
                        children: [
                          Icon(Icons.unarchive_outlined, size: 16, color: AppTheme.getColors(context).textPrimary),
                          const SizedBox(width: 8),
                          const Text('Unarchive'),
                        ],
                      ),
                    )
                  else
                    PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined, size: 16, color: AppTheme.getColors(context).textPrimary),
                          const SizedBox(width: 8),
                          const Text('Archive'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: AppTheme.accentRed),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppTheme.accentRed)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Inline Expandable Sessions Section
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppTheme.getColors(context).divider.withValues(alpha: 0.6)),
            const SizedBox(height: 10),
            _WorkItemSessionsList(
              workItem: item,
              sessionsAsync: sessionsAsync,
              peopleMap: widget.peopleMap,
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkItemSessionsList extends ConsumerWidget {
  final WorkItem workItem;
  final AsyncValue<List<Session>> sessionsAsync;
  final Map<String, Person> peopleMap;

  const _WorkItemSessionsList({
    required this.workItem,
    required this.sessionsAsync,
    required this.peopleMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppTheme.getColors(context);
    final dateFormat = DateFormat('MMM d, yyyy • HH:mm');
    final timeFormat = DateFormat('HH:mm');

    return sessionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
          ),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Failed to load sessions: $err',
          style: const TextStyle(fontSize: 12, color: AppTheme.accentRed),
        ),
      ),
      data: (sessions) {
        if (sessions.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: colors.card.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'No sessions recorded yet for this task.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: colors.textSecondary),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.divider.withValues(alpha: 0.6)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: sessions.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: colors.divider.withValues(alpha: 0.6)),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final start = session.startTime.toLocal();
              final end = session.endTime?.toLocal();
              final isRunning = end == null;
              final durationStr = TimerService.formatDuration(session.duration, includeSeconds: true);
              final sessionPeople = session.peopleIds.map((id) => peopleMap[id]).whereType<Person>().toList();

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: index == 0
                      ? const BorderRadius.vertical(top: Radius.circular(8))
                      : index == sessions.length - 1
                          ? const BorderRadius.vertical(bottom: Radius.circular(8))
                          : BorderRadius.zero,
                  onTap: () async {
                    final record = SessionExportRecord(
                      session: session,
                      workItem: workItem,
                      grossDuration: session.duration,
                      idleDuration: Duration.zero,
                      netActiveDuration: session.duration,
                    );
                    await SessionEditDialog.show(context, record);
                    ref.invalidate(sessionsForWorkItemProvider(workItem.id));
                    ref.invalidate(taskTotalDurationProvider(workItem.id));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          isRunning ? Icons.play_circle : Icons.schedule,
                          size: 14,
                          color: isRunning ? AppTheme.accentGreen : colors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isRunning
                                        ? '${dateFormat.format(start)} - Running'
                                        : '${dateFormat.format(start)} - ${timeFormat.format(end)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isRunning ? AppTheme.accentGreen : colors.textPrimary,
                                    ),
                                  ),
                                  if (isRunning) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentGreen.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'ACTIVE',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if ((session.notes ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(Icons.notes, size: 11, color: colors.textSecondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        session.notes!.trim(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: colors.textSecondary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (sessionPeople.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 2,
                                  children: sessionPeople.map((p) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: colors.surface,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.person, size: 10, color: colors.textSecondary),
                                        const SizedBox(width: 3),
                                        Text(p.name, style: TextStyle(fontSize: 10, color: colors.textSecondary)),
                                      ],
                                    ),
                                  )).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          durationStr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isRunning ? AppTheme.accentGreen : AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.edit_outlined, size: 14, color: colors.textSecondary.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TaskDurationBadge extends ConsumerWidget {
  final String workItemId;
  final bool isItemActive;

  const _TaskDurationBadge({
    required this.workItemId,
    required this.isItemActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isItemActive) {
      final elapsed = ref.watch(timerProvider.select((s) => s.value?.elapsed ?? Duration.zero));
      final formatted = TimerService.formatDuration(elapsed, includeSeconds: true);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, size: 11, color: AppTheme.accentGreen),
            const SizedBox(width: 4),
            Text(
              formatted,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGreen,
              ),
            ),
          ],
        ),
      );
    }

    final totalDurationAsync = ref.watch(taskTotalDurationProvider(workItemId));
    return totalDurationAsync.when(
      data: (dur) {
        if (dur == Duration.zero) return const SizedBox.shrink();
        final formatted = TimerService.formatDuration(dur, compact: true);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.getColors(context).card,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 11, color: AppTheme.getColors(context).textSecondary),
              const SizedBox(width: 4),
              Text(
                formatted,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                  color: AppTheme.getColors(context).textSecondary,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

