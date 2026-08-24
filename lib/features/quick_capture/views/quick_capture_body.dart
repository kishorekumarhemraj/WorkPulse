import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/core/widgets/app_select.dart';
import 'package:workpulse/core/widgets/keycap.dart';
import 'package:workpulse/core/widgets/searchable_multi_select.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/attributes/widgets/dynamic_attribute_fields.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/quick_capture/models/quick_capture_state.dart';
import 'package:workpulse/features/quick_capture/providers/quick_capture_provider.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/timer/views/task_switch_dialog.dart';

/// Quick Capture itself: the search field, the result list, and the bar of
/// classification controls beneath it — everything except the window or dialog
/// chrome around it.
///
/// Quick Capture is reached two ways, and the two used to be separate ~700-line
/// files. `QuickCaptureDialog` came first, as an in-app `showDialog`. When the
/// macOS focus-isolation requirement arrived (AGENTS.md rule 3: the HUD appears
/// over whatever application the user is in, without pulling the dashboard into
/// focus), a dialog could no longer do the job — a route lives inside the app's
/// own window. The window itself had to become the HUD, which meant the content
/// had to be a root widget rather than a route, and the file was copied rather
/// than split.
///
/// The only thing that actually differs between the two is how they close:
/// `Navigator.pop` for the dialog, a callback for the standalone window, which
/// has no route to pop. That is what [onDismiss] abstracts, and it is the whole
/// reason this widget can be shared.
class QuickCaptureBody extends ConsumerStatefulWidget {
  /// Closes whatever is hosting Quick Capture. Called once the user has started
  /// tracking, and on cancel.
  final VoidCallback onDismiss;

  /// Whether the result list should fill the remaining height.
  ///
  /// True in the standalone window, which is sized to the HUD and whose bottom
  /// bar must sit on the bottom edge. False in the dialog, which shrink-wraps
  /// its content up to a maximum height.
  final bool expandResults;

  const QuickCaptureBody({
    super.key,
    required this.onDismiss,
    this.expandResults = false,
  });

  @override
  ConsumerState<QuickCaptureBody> createState() => _QuickCaptureBodyState();
}

class _QuickCaptureBodyState extends ConsumerState<QuickCaptureBody> {
  /// The result list is capped rather than scrolled: Quick Capture is for
  /// getting a timer running in one gesture, not for browsing.
  static const int _maxResults = 5;

  late final TextEditingController _searchController;
  late final FocusNode _inputFocusNode;
  final Map<String, dynamic> _attributeValues = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Arrow keys are handled on the input's own node as well as on the wrapper
    // below, because a TextField consumes them before an ancestor sees them.
    _inputFocusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          ref
              .read(quickCaptureProvider.notifier)
              .selectNext(_currentResults().totalItems);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          ref.read(quickCaptureProvider.notifier).selectPrevious();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  /// The matches for the current query, derived the same way in the key handler
  /// and in [build] — this used to be written out three times per file, twice
  /// over, and the copies were free to disagree.
  _QuickCaptureResults _currentResults() {
    final query = ref.read(quickCaptureProvider).query;
    final workItems = ref.read(workItemsProvider).value ?? const <WorkItem>[];
    return _QuickCaptureResults.from(query: query, workItems: workItems);
  }

  Future<void> _handleConfirm({
    required _QuickCaptureResults results,
    int? overrideIndex,
  }) async {
    final selectedIndex =
        overrideIndex ?? ref.read(quickCaptureProvider).selectedIndex;
    if (results.totalItems == 0) return;

    if (results.isCreateIndex(selectedIndex)) {
      final created =
          await ref.read(quickCaptureProvider.notifier).createAndStartTask(
                name: results.query,
                attributeValues: _attributeValues,
              );
      if (mounted && created != null) widget.onDismiss();
      return;
    }

    if (selectedIndex < 0 || selectedIndex >= results.tasks.length) return;

    final targetTask = results.tasks[selectedIndex];
    final timerState = ref.read(timerProvider).value;
    final isTrackingSomethingElse = timerState != null &&
        timerState.isRunning &&
        timerState.activeWorkItem != null &&
        timerState.activeWorkItem!.id != targetTask.id;

    if (isTrackingSomethingElse) {
      // Exactly one session may be active, so a switch is confirmed first.
      ref.read(timerProvider.notifier).requestSwitch(targetTask);
      if (!mounted) return;
      final switched = await TaskSwitchDialog.show(
        context,
        currentItem: timerState.activeWorkItem!,
        currentElapsed: timerState.elapsed,
        targetItem: targetTask,
      );
      if (switched == true && mounted) widget.onDismiss();
      return;
    }

    await ref.read(quickCaptureProvider.notifier).startExistingTask(targetTask);
    if (mounted) widget.onDismiss();
  }

  void _handleCancel() {
    ref.read(quickCaptureProvider.notifier).reset();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final qcState = ref.watch(quickCaptureProvider);
    final workItems = ref.watch(workItemsProvider).value ?? const <WorkItem>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final people = ref.watch(peopleProvider).value ?? const <Person>[];
    final attributeDefinitions =
        ref.watch(attributeDefinitionsProvider).value ??
            const <AttributeDefinition>[];

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

    final results = _QuickCaptureResults.from(
      query: qcState.query,
      workItems: workItems,
    );

    final resultList = ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: results.totalItems == 0 ? 1 : results.totalItems,
      itemBuilder: (context, index) {
        if (results.totalItems == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Center(
              child: Text(
                'Type a task name to track',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ),
          );
        }

        final isSelected = qcState.selectedIndex == index;

        if (results.isCreateIndex(index)) {
          return _buildCreateOption(results, isSelected);
        }

        final task = results.tasks[index];
        return _buildTaskResultItem(
          task: task,
          project: projectMap[task.projectId],
          category: categoryMap[task.categoryId],
          isSelected: isSelected,
          index: index,
          results: results,
        );
      },
    );

    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _handleCancel();
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
          _handleConfirm(results: results);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          ref
              .read(quickCaptureProvider.notifier)
              .selectNext(results.totalItems);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          ref.read(quickCaptureProvider.notifier).selectPrevious();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        mainAxisSize:
            widget.expandResults ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchHeader(results),
          if (widget.expandResults)
            Expanded(child: resultList)
          else
            Flexible(child: resultList),
          _buildConfigurationBar(
            projects: projects,
            categories: categories,
            tags: tags,
            people: people,
            attributes: quickCaptureAttributes,
            qcState: qcState,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(_QuickCaptureResults results) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 22, color: colors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _inputFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _handleConfirm(results: results),
              style: TextStyle(
                fontSize: 16,
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search tasks or type new task name...',
                hintStyle: TextStyle(fontSize: 15, color: colors.textSecondary),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                suffixIcon: results.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: Icon(Icons.close,
                            size: 16, color: colors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(quickCaptureProvider.notifier).setQuery('');
                        },
                      ),
              ),
              onChanged: (value) =>
                  ref.read(quickCaptureProvider.notifier).setQuery(value),
            ),
          ),
          const SizedBox(width: 12),
          const Keycap('↵ Track'),
          const SizedBox(width: 6),
          const Keycap('esc'),
        ],
      ),
    );
  }

  Widget _buildConfigurationBar({
    required List<Project> projects,
    required List<Category> categories,
    required List<Tag> tags,
    required List<Person> people,
    required List<AttributeDefinition> attributes,
    required QuickCaptureState qcState,
  }) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        border: Border(top: BorderSide(color: colors.divider, width: 1)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (projects.isNotEmpty || categories.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (projects.isNotEmpty)
                      Expanded(
                        child: AppSelect<String>(
                          label: 'Project',
                          value: projects
                                  .any((p) => p.id == qcState.selectedProjectId)
                              ? qcState.selectedProjectId
                              : projects.first.id,
                          placeholder: 'Select Project',
                          maxTriggerWidth: double.infinity,
                          options: projects
                              .map((p) => SelectOption(
                                    value: p.id,
                                    label: p.name,
                                    color: ColorUtils.parseHex(p.colorHex),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              ref
                                  .read(quickCaptureProvider.notifier)
                                  .setProject(value);
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
                          onChanged: (value) {
                            if (value != null) {
                              ref
                                  .read(quickCaptureProvider.notifier)
                                  .setCategory(value);
                            }
                          },
                        ),
                      ),
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
                  onChanged: (ids) =>
                      ref.read(quickCaptureProvider.notifier).setTagIds(ids),
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
                  onChanged: (ids) =>
                      ref.read(quickCaptureProvider.notifier).setPeopleIds(ids),
                  hintText: 'Search people...',
                  emptyStateText: 'No people added yet',
                ),
              ],
              if (attributes.isNotEmpty) ...[
                const SizedBox(height: 12),
                DynamicAttributeFields(
                  definitions: attributes,
                  values: _attributeValues,
                  onValueChanged: (defId, value) {
                    setState(() => _attributeValues[defId] = value);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskResultItem({
    required WorkItem task,
    required Project? project,
    required Category? category,
    required bool isSelected,
    required int index,
    required _QuickCaptureResults results,
  }) {
    final colors = context.colors;
    final projectColor = ColorUtils.parseHex(project?.colorHex);

    return Container(
      decoration: BoxDecoration(
        border: isSelected
            ? Border(left: BorderSide(color: colors.accent, width: 3))
            : null,
      ),
      child: Material(
        color: isSelected
            ? colors.accent.withValues(alpha: 0.15)
            : Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: () {
            ref.read(quickCaptureProvider.notifier).setSelectedIndex(index);
            _handleConfirm(results: results, overrideIndex: index);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_outline,
                  size: 18,
                  color: isSelected ? colors.accent : colors.textSecondary,
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
                          color:
                              isSelected ? colors.accent : colors.textPrimary,
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
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              project.name,
                              style:
                                  TextStyle(fontSize: 12, color: projectColor),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (category != null)
                            Text(
                              category.name,
                              style: TextStyle(
                                  fontSize: 12, color: colors.textSecondary),
                            ),
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
                      color: colors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateOption(_QuickCaptureResults results, bool isSelected) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        border: isSelected
            ? Border(left: BorderSide(color: colors.success, width: 3))
            : null,
      ),
      child: Material(
        color: isSelected
            ? colors.success.withValues(alpha: 0.15)
            : Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: () => _handleConfirm(
            results: results,
            overrideIndex: results.tasks.length,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: isSelected
                      ? colors.success
                      : colors.success.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: 'Create and track new task: ',
                      style:
                          TextStyle(fontSize: 13, color: colors.textSecondary),
                      children: [
                        TextSpan(
                          text: '"${results.query}"',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
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
                    color: colors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the current query matches, and whether a "create it" row is offered.
///
/// Both quick capture surfaces derived this inline, in the key handler and
/// again in `build` — four copies of the same filter that were free to drift
/// apart. Deriving it in one place also makes the selection arithmetic
/// ([isCreateIndex]) statable instead of repeated.
@immutable
class _QuickCaptureResults {
  final String query;
  final List<WorkItem> tasks;
  final bool showCreateOption;

  const _QuickCaptureResults({
    required this.query,
    required this.tasks,
    required this.showCreateOption,
  });

  factory _QuickCaptureResults.from({
    required String query,
    required List<WorkItem> workItems,
    int maxResults = _QuickCaptureBodyState._maxResults,
  }) {
    final normalized = query.trim().toLowerCase();
    final tasks = workItems
        .where((item) =>
            !item.isArchived &&
            (normalized.isEmpty ||
                item.name.toLowerCase().contains(normalized)))
        .take(maxResults)
        .toList();

    // An exact match is already offered as a result, so offering to create a
    // duplicate of it would be noise.
    final hasExactMatch = tasks.any((t) => t.name.toLowerCase() == normalized);

    return _QuickCaptureResults(
      query: query,
      tasks: tasks,
      showCreateOption: normalized.isNotEmpty && !hasExactMatch,
    );
  }

  int get totalItems => tasks.length + (showCreateOption ? 1 : 0);

  /// Whether [index] addresses the trailing "create and track" row.
  bool isCreateIndex(int index) => showCreateOption && index == tasks.length;
}
