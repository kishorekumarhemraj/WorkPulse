import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/core/widgets/searchable_multi_select.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/attributes/widgets/dynamic_attribute_fields.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/quick_capture/providers/quick_capture_provider.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/timer/views/task_switch_dialog.dart';

class QuickCaptureDialog extends ConsumerStatefulWidget {
  const QuickCaptureDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: true,
      builder: (context) => const QuickCaptureDialog(),
    );
  }

  @override
  ConsumerState<QuickCaptureDialog> createState() => _QuickCaptureDialogState();
}

class _QuickCaptureDialogState extends ConsumerState<QuickCaptureDialog> {
  late final TextEditingController _searchController;
  late final FocusNode _inputFocusNode;
  final Map<String, dynamic> _attributeValues = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _inputFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm(
    List<WorkItem> matchingTasks,
    bool showCreateOption,
    String query,
  ) async {
    final qcState = ref.read(quickCaptureProvider);
    final totalCount = matchingTasks.length + (showCreateOption ? 1 : 0);
    if (totalCount == 0) return;

    final isNewTaskSelected =
        showCreateOption && qcState.selectedIndex == matchingTasks.length;

    if (isNewTaskSelected) {
      // Create and start new task
      final created =
          await ref.read(quickCaptureProvider.notifier).createAndStartTask(
                name: query,
                attributeValues: _attributeValues,
              );
      if (mounted && created != null) {
        Navigator.of(context).pop();
      }
    } else if (qcState.selectedIndex < matchingTasks.length) {
      // Select existing task
      final targetTask = matchingTasks[qcState.selectedIndex];
      final timerState = ref.read(timerProvider).value;

      if (timerState != null &&
          timerState.isRunning &&
          timerState.activeWorkItem != null &&
          timerState.activeWorkItem!.id != targetTask.id) {
        ref.read(timerProvider.notifier).requestSwitch(targetTask);
        final switched = await TaskSwitchDialog.show(
          context,
          currentItem: timerState.activeWorkItem!,
          currentElapsed: timerState.elapsed,
          targetItem: targetTask,
        );
        if (switched == true && mounted) {
          Navigator.of(context).pop();
        }
      } else {
        await ref
            .read(quickCaptureProvider.notifier)
            .startExistingTask(targetTask);
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final qcState = ref.watch(quickCaptureProvider);
    final workItems = ref.watch(workItemsProvider).value ?? [];
    final projects = ref.watch(projectsProvider).value ?? [];
    final categories = ref.watch(categoriesProvider).value ?? [];
    final tags = ref.watch(tagsProvider).value ?? [];
    final people = ref.watch(peopleProvider).value ?? [];
    final attributeDefinitions =
        ref.watch(attributeDefinitionsProvider).value ?? [];
    final quickCaptureAttributes = attributeDefinitions
        .where(
          (d) =>
              d.scope == AttributeScope.task &&
              d.enabled &&
              !d.isArchived &&
              d.showInQuickCapture,
        )
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final projectMap = {for (final p in projects) p.id: p};
    final categoryMap = {for (final c in categories) c.id: c};

    final query = qcState.query.trim().toLowerCase();
    final matchingTasks = workItems
        .where((item) {
          if (item.isArchived) return false;
          if (query.isEmpty) return true;
          return item.name.toLowerCase().contains(query);
        })
        .take(5)
        .toList();

    final hasExactMatch =
        matchingTasks.any((t) => t.name.toLowerCase() == query);
    final showCreateOption = query.isNotEmpty && !hasExactMatch;
    final totalItems = matchingTasks.length + (showCreateOption ? 1 : 0);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            ref.read(quickCaptureProvider.notifier).reset();
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            ref.read(quickCaptureProvider.notifier).selectNext(totalItems);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            ref.read(quickCaptureProvider.notifier).selectPrevious();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.tab) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              FocusScope.of(context).previousFocus();
            } else {
              FocusScope.of(context).nextFocus();
            }
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            _handleConfirm(matchingTasks, showCreateOption, qcState.query);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 620,
            constraints: const BoxConstraints(maxHeight: 520),
            decoration: BoxDecoration(
              color: AppTheme.getColors(context).surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.getColors(context).divider, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  offset: const Offset(0, 12),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Input Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: AppTheme.getColors(context).divider,
                            width: 1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search,
                          size: 22, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _inputFocusNode,
                          autofocus: true,
                          style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.getColors(context).textPrimary,
                              fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Search tasks or type new task name...',
                            hintStyle: TextStyle(
                                fontSize: 15,
                                color:
                                    AppTheme.getColors(context).textSecondary),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onChanged: (val) => ref
                              .read(quickCaptureProvider.notifier)
                              .setQuery(val),
                        ),
                      ),
                      if (qcState.query.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.close,
                              size: 16,
                              color: AppTheme.getColors(context).textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(quickCaptureProvider.notifier)
                                .setQuery('');
                          },
                        ),
                      // Shortcut Pill Badges
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.getColors(context).card,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppTheme.getColors(context).divider),
                        ),
                        child: Text(
                          '↵ Track',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.getColors(context).textSecondary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.getColors(context).card,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppTheme.getColors(context).divider),
                        ),
                        child: Text(
                          'esc',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.getColors(context).textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),

                // Results List
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: totalItems == 0 ? 1 : totalItems,
                    itemBuilder: (context, index) {
                      if (totalItems == 0) {
                        return Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 24, horizontal: 16),
                          child: Center(
                            child: Text(
                              'Type a task name to track',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.getColors(context)
                                      .textSecondary),
                            ),
                          ),
                        );
                      }

                      final isCreateOption =
                          showCreateOption && index == matchingTasks.length;
                      final isSelected = qcState.selectedIndex == index;

                      if (isCreateOption) {
                        return _buildCreateOption(qcState.query, isSelected);
                      }

                      final task = matchingTasks[index];
                      final project = projectMap[task.projectId];
                      final category = categoryMap[task.categoryId];

                      return _buildTaskResultItem(
                          task, project, category, isSelected, index);
                    },
                  ),
                ),

                // Bottom Configuration Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: AppTheme.getColors(context).card,
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(14)),
                    border: Border(
                        top: BorderSide(
                            color: AppTheme.getColors(context).divider,
                            width: 1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (projects.isNotEmpty) ...[
                            Icon(Icons.folder_outlined,
                                size: 14,
                                color:
                                    AppTheme.getColors(context).textSecondary),
                            const SizedBox(width: 6),
                            DropdownButton<String>(
                              value: projects.any(
                                      (p) => p.id == qcState.selectedProjectId)
                                  ? qcState.selectedProjectId
                                  : projects.first.id,
                              dropdownColor:
                                  AppTheme.getColors(context).surface,
                              underline: const SizedBox.shrink(),
                              isDense: true,
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      AppTheme.getColors(context).textPrimary),
                              items: projects.map((p) {
                                final col = ColorUtils.parseHex(p.colorHex);
                                return DropdownMenuItem(
                                  value: p.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                              color: col,
                                              shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Text(p.name,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.getColors(context)
                                                  .textPrimary)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) => ref
                                  .read(quickCaptureProvider.notifier)
                                  .setProject(val),
                            ),
                            const SizedBox(width: 14),
                          ],
                          if (categories.isNotEmpty) ...[
                            Icon(Icons.category_outlined,
                                size: 14,
                                color:
                                    AppTheme.getColors(context).textSecondary),
                            const SizedBox(width: 6),
                            DropdownButton<String>(
                              value: categories.any(
                                      (c) => c.id == qcState.selectedCategoryId)
                                  ? qcState.selectedCategoryId
                                  : categories.first.id,
                              dropdownColor:
                                  AppTheme.getColors(context).surface,
                              underline: const SizedBox.shrink(),
                              isDense: true,
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      AppTheme.getColors(context).textPrimary),
                              items: categories.map((c) {
                                return DropdownMenuItem(
                                  value: c.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(IconUtils.getIcon(c.iconName),
                                          size: 12,
                                          color: AppTheme.primaryColor),
                                      const SizedBox(width: 6),
                                      Text(c.name,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.getColors(context)
                                                  .textPrimary)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) => ref
                                  .read(quickCaptureProvider.notifier)
                                  .setCategory(val),
                            ),
                          ],
                        ],
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SearchableMultiSelect(
                          allItems: tags
                              .map((t) => SearchableMultiSelectItem(
                                    id: t.id,
                                    label: t.name,
                                    color: ColorUtils.parseHex(t.colorHex),
                                  ))
                              .toList(),
                          selectedIds: qcState.selectedTagIds,
                          onChanged: (ids) => ref
                              .read(quickCaptureProvider.notifier)
                              .setTagIds(ids),
                          hintText: 'Search tags...',
                          emptyStateText: 'No tags created yet',
                        ),
                      ],
                      if (people.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SearchableMultiSelect(
                          allItems: people
                              .map((person) => SearchableMultiSelectItem(
                                    id: person.id,
                                    label: person.name,
                                    icon: Icons.person_outline,
                                  ))
                              .toList(),
                          selectedIds: qcState.selectedPeopleIds,
                          onChanged: (ids) => ref
                              .read(quickCaptureProvider.notifier)
                              .setPeopleIds(ids),
                          hintText: 'Search people...',
                          emptyStateText: 'No people added yet',
                        ),
                      ],
                      if (quickCaptureAttributes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DynamicAttributeFields(
                          definitions: quickCaptureAttributes,
                          values: _attributeValues,
                          onValueChanged: (defId, val) {
                            setState(() {
                              _attributeValues[defId] = val;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskResultItem(
    WorkItem task,
    Project? project,
    Category? category,
    bool isSelected,
    int index,
  ) {
    final projectColor = ColorUtils.parseHex(project?.colorHex);

    return Container(
      decoration: BoxDecoration(
        border: isSelected
            ? Border(left: BorderSide(color: AppTheme.primaryColor, width: 3))
            : null,
      ),
      child: Material(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.15)
            : Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(quickCaptureProvider.notifier).setSelectedIndex(index);
            _handleConfirm([task], false, '');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_outline,
                  size: 18,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.getColors(context).textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.getColors(context).textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (project != null) ...[
                            Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: projectColor,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(project.name,
                                style: TextStyle(
                                    fontSize: 11, color: projectColor)),
                            const SizedBox(width: 8),
                          ],
                          if (category != null) ...[
                            Text(category.name,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.getColors(context)
                                        .textSecondary)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Text(
                    '↵ to track',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateOption(String query, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        border: isSelected
            ? Border(left: BorderSide(color: AppTheme.accentGreen, width: 3))
            : null,
      ),
      child: Material(
        color: isSelected
            ? AppTheme.accentGreen.withValues(alpha: 0.15)
            : Colors.transparent,
        child: InkWell(
          onTap: () {
            _handleConfirm([], true, query);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: isSelected
                      ? AppTheme.accentGreen
                      : AppTheme.accentGreen.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: 'Create and track new task: ',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.getColors(context).textSecondary),
                      children: [
                        TextSpan(
                          text: '"$query"',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.getColors(context).textPrimary),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '↵ to create',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.accentGreen,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
