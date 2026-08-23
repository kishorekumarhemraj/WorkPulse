import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Work Items',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tracked tasks, issues, and activities across all projects',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryDark),
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
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.textSecondaryDark),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.dividerDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.dividerDark),
                      ),
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
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: filter.projectId != null ? AppTheme.primaryColor : AppTheme.dividerDark,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: filter.projectId,
                          hint: const Text('All Projects', style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryDark)),
                          icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.textSecondaryDark),
                          dropdownColor: AppTheme.surfaceDark,
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
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: filter.categoryId != null ? AppTheme.primaryColor : AppTheme.dividerDark,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: filter.categoryId,
                          hint: const Text('All Categories', style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryDark)),
                          icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.textSecondaryDark),
                          dropdownColor: AppTheme.surfaceDark,
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
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: filter.tagId != null ? AppTheme.primaryColor : AppTheme.dividerDark,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: filter.tagId,
                          hint: const Text('All Tags', style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryDark)),
                          icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.textSecondaryDark),
                          dropdownColor: AppTheme.surfaceDark,
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
                  backgroundColor: AppTheme.surfaceDark,
                  selectedColor: AppTheme.accentOrange.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: filter.includeArchived ? AppTheme.accentOrange : AppTheme.textSecondaryDark,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: filter.includeArchived ? AppTheme.accentOrange : AppTheme.dividerDark,
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
                          Icon(Icons.assignment_outlined, size: 48, color: AppTheme.textSecondaryDark.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            filter.hasActiveFilters ? 'No tasks match current filters' : 'No tasks created yet',
                            style: const TextStyle(fontSize: 16, color: AppTheme.textSecondaryDark),
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

class _WorkItemCard extends ConsumerWidget {
  final WorkItem item;
  final Project? project;
  final Category? category;
  final List<Tag> tags;
  final List<Person> people;

  const _WorkItemCard({
    required this.item,
    required this.project,
    required this.category,
    required this.tags,
    required this.people,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectColor = ColorUtils.parseHex(project?.colorHex);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.isArchived ? AppTheme.dividerDark.withValues(alpha: 0.5) : AppTheme.dividerDark,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project color vertical strip
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: projectColor,
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
                          color: item.isArchived ? AppTheme.textSecondaryDark : AppTheme.textPrimaryDark,
                          decoration: item.isArchived ? TextDecoration.lineThrough : null,
                        ),
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
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),

                // Meta badges: Project, Category, Tags, People
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
                              project!.name,
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
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(IconUtils.getIcon(category!.iconName), size: 12, color: AppTheme.textSecondaryDark),
                            const SizedBox(width: 4),
                            Text(
                              category!.name,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryDark),
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
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, size: 11, color: AppTheme.textSecondaryDark),
                            const SizedBox(width: 4),
                            Text(
                              p.name,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryDark),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),

          // Actions Popup Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondaryDark),
            color: AppTheme.surfaceDark,
            onSelected: (value) async {
              if (value == 'edit') {
                await TaskFormDialog.show(context, workItem: item);
              } else if (value == 'archive') {
                await ref.read(workItemsProvider.notifier).archiveWorkItem(item.id);
              } else if (value == 'unarchive') {
                await ref.read(workItemsProvider.notifier).unarchiveWorkItem(item.id);
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.surfaceDark,
                    title: const Text('Delete Task', style: TextStyle(color: AppTheme.textPrimaryDark)),
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
                  await ref.read(workItemsProvider.notifier).deleteWorkItem(item.id);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: AppTheme.textPrimaryDark),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              if (item.isArchived)
                const PopupMenuItem(
                  value: 'unarchive',
                  child: Row(
                    children: [
                      Icon(Icons.unarchive_outlined, size: 16, color: AppTheme.textPrimaryDark),
                      SizedBox(width: 8),
                      Text('Unarchive'),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'archive',
                  child: Row(
                    children: [
                      Icon(Icons.archive_outlined, size: 16, color: AppTheme.textPrimaryDark),
                      SizedBox(width: 8),
                      Text('Archive'),
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
    );
  }
}
