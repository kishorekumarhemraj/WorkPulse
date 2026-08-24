import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/widgets/keycap.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/core/widgets/app_select.dart';
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
    _inputFocusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            final qcState = ref.read(quickCaptureProvider);
            final query = qcState.query.trim().toLowerCase();
            final workItems = ref.read(workItemsProvider).value ?? [];
            final matchingTasks = workItems
                .where((item) =>
                    !item.isArchived &&
                    (query.isEmpty || item.name.toLowerCase().contains(query)))
                .take(5)
                .toList();
            final hasExactMatch =
                matchingTasks.any((t) => t.name.toLowerCase() == query);
            final showCreateOption = query.isNotEmpty && !hasExactMatch;
            final totalItems =
                matchingTasks.length + (showCreateOption ? 1 : 0);

            ref.read(quickCaptureProvider.notifier).selectNext(totalItems);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            ref.read(quickCaptureProvider.notifier).selectPrevious();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm({
    required List<WorkItem> matchingTasks,
    required bool showCreateOption,
    required String query,
    int? overrideIndex,
  }) async {
    final qcState = ref.read(quickCaptureProvider);
    final selectedIndex = overrideIndex ?? qcState.selectedIndex;
    final totalCount = matchingTasks.length + (showCreateOption ? 1 : 0);
    if (totalCount == 0) return;

    final isNewTaskSelected =
        showCreateOption && selectedIndex == matchingTasks.length;

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
    } else if (selectedIndex >= 0 && selectedIndex < matchingTasks.length) {
      // Select existing task
      final targetTask = matchingTasks[selectedIndex];
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
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            ref.read(quickCaptureProvider.notifier).reset();
            Navigator.of(context).pop();
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
            _handleConfirm(
              matchingTasks: matchingTasks,
              showCreateOption: showCreateOption,
              query: qcState.query,
            );
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
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 620,
            constraints: const BoxConstraints(maxHeight: 640, minHeight: 400),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: Radii.xlAll,
              border: Border.all(color: context.colors.divider, width: 1.2),
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
                            color: context.colors.divider, width: 1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search,
                          size: 22, color: context.colors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _inputFocusNode,
                          autofocus: true,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (val) {
                            _handleConfirm(
                              matchingTasks: matchingTasks,
                              showCreateOption: showCreateOption,
                              query: qcState.query,
                            );
                          },
                          style: TextStyle(
                              fontSize: 16,
                              color: context.colors.textPrimary,
                              fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Search tasks or type new task name...',
                            hintStyle: TextStyle(
                                fontSize: 15,
                                color: context.colors.textSecondary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            suffixIcon: qcState.query.isNotEmpty
                                ? IconButton(
                                    tooltip: 'Clear search',
                                    icon: Icon(Icons.close,
                                        size: 16,
                                        color: context.colors.textSecondary),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref
                                          .read(quickCaptureProvider.notifier)
                                          .setQuery('');
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) => ref
                              .read(quickCaptureProvider.notifier)
                              .setQuery(val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Shortcut Pill Badges
                      const Keycap('↵ Track'),
                      const SizedBox(width: 6),
                      const Keycap('esc'),
                    ],
                  ),
                ),

                // Results List
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: totalItems == 0 ? 1 : totalItems,
                    itemBuilder: (context, index) {
                      if (totalItems == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 24, horizontal: 16),
                          child: Center(
                            child: Text(
                              'Type a task name to track',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.textSecondary),
                            ),
                          ),
                        );
                      }

                      final isCreateOption =
                          showCreateOption && index == matchingTasks.length;
                      final isSelected = qcState.selectedIndex == index;

                      if (isCreateOption) {
                        return _buildCreateOption(
                            qcState.query, isSelected, matchingTasks);
                      }

                      final task = matchingTasks[index];
                      final project = projectMap[task.projectId];
                      final category = categoryMap[task.categoryId];

                      return _buildTaskResultItem(
                        task,
                        project,
                        category,
                        isSelected,
                        index,
                        matchingTasks,
                        showCreateOption,
                        qcState.query,
                      );
                    },
                  ),
                ),

                // Bottom Configuration Bar
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14)),
                    border: Border(
                        top: BorderSide(
                            color: context.colors.divider, width: 1)),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (projects.isNotEmpty || categories.isNotEmpty) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (projects.isNotEmpty)
                                  Expanded(
                                    child: AppSelect<String>(
                                      label: 'Project',
                                      value: projects.any(
                                              (p) => p.id == qcState.selectedProjectId)
                                          ? qcState.selectedProjectId
                                          : projects.first.id,
                                      placeholder: 'Select Project',
                                      maxTriggerWidth: double.infinity,
                                      options: projects
                                          .map((p) => SelectOption(
                                                value: p.id,
                                                label: p.name,
                                                color:
                                                    ColorUtils.parseHex(p.colorHex),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          ref
                                              .read(quickCaptureProvider.notifier)
                                              .setProject(val);
                                        }
                                      },
                                    ),
                                  ),
                                if (projects.isNotEmpty && categories.isNotEmpty)
                                  const SizedBox(width: 12),
                                if (categories.isNotEmpty)
                                  Expanded(
                                    child: AppSelect<String>(
                                      label: 'Category',
                                      value: categories.any(
                                              (c) => c.id == qcState.selectedCategoryId)
                                          ? qcState.selectedCategoryId
                                          : categories.first.id,
                                      placeholder: 'Select Category',
                                      maxTriggerWidth: double.infinity,
                                      options: categories
                                          .map((c) => SelectOption(
                                                value: c.id,
                                                label: c.name,
                                                icon: IconUtils.getIcon(c.iconName),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          ref
                                              .read(quickCaptureProvider.notifier)
                                              .setCategory(val);
                                        }
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ],
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
    List<WorkItem> matchingTasks,
    bool showCreateOption,
    String query,
  ) {
    final projectColor = ColorUtils.parseHex(project?.colorHex);

    return Container(
      decoration: BoxDecoration(
        border: isSelected
            ? Border(left: BorderSide(color: context.colors.accent, width: 3))
            : null,
      ),
      child: Material(
        color: isSelected
            ? context.colors.accent.withValues(alpha: 0.15)
            : Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: () {
            ref.read(quickCaptureProvider.notifier).setSelectedIndex(index);
            _handleConfirm(
              matchingTasks: matchingTasks,
              showCreateOption: showCreateOption,
              query: query,
              overrideIndex: index,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_outline,
                  size: 18,
                  color: isSelected
                      ? context.colors.accent
                      : context.colors.textSecondary,
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
                              ? context.colors.accent
                              : context.colors.textPrimary,
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
                                    fontSize: 12, color: projectColor)),
                            const SizedBox(width: 8),
                          ],
                          if (category != null) ...[
                            Text(category.name,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.textSecondary)),
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
                        fontSize: 12,
                        color: context.colors.accent,
                        fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateOption(
    String query,
    bool isSelected,
    List<WorkItem> matchingTasks,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: isSelected
            ? Border(left: BorderSide(color: context.colors.success, width: 3))
            : null,
      ),
      child: Material(
        color: isSelected
            ? context.colors.success.withValues(alpha: 0.15)
            : Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: () {
            _handleConfirm(
              matchingTasks: matchingTasks,
              showCreateOption: true,
              query: query,
              overrideIndex: matchingTasks.length,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: isSelected
                      ? context.colors.success
                      : context.colors.success.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: 'Create and track new task: ',
                      style: TextStyle(
                          fontSize: 13, color: context.colors.textSecondary),
                      children: [
                        TextSpan(
                          text: '"$query"',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: context.colors.textPrimary),
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
                      fontSize: 12,
                      color: context.colors.success,
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
