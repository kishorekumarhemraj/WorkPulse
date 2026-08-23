import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/core/widgets/searchable_multi_select.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/attributes/widgets/dynamic_attribute_fields.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/categories/views/category_form_dialog.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/people/views/person_form_dialog.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/projects/views/project_form_dialog.dart';
import 'package:workpulse/features/reports/views/session_edit_dialog.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tags/views/tag_form_dialog.dart';
import 'package:workpulse/features/tasks/providers/task_sessions_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';

const _uuid = Uuid();

class TaskFormDialog extends ConsumerStatefulWidget {
  final WorkItem? workItem;
  final String? initialProjectId;
  final String? initialCategoryId;

  const TaskFormDialog({
    super.key,
    this.workItem,
    this.initialProjectId,
    this.initialCategoryId,
  });

  static Future<WorkItem?> show(
    BuildContext context, {
    WorkItem? workItem,
    String? initialProjectId,
    String? initialCategoryId,
  }) {
    return showDialog<WorkItem>(
      context: context,
      barrierDismissible: true,
      builder: (context) => TaskFormDialog(
        workItem: workItem,
        initialProjectId: initialProjectId,
        initialCategoryId: initialCategoryId,
      ),
    );
  }

  @override
  ConsumerState<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends ConsumerState<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  String? _selectedProjectId;
  String? _selectedCategoryId;
  late List<String> _selectedTagIds;
  late List<String> _selectedPeopleIds;
  final Map<String, dynamic> _attributeValues = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.workItem?.name ?? '');

    _selectedProjectId = widget.workItem?.projectId ?? widget.initialProjectId;
    _selectedCategoryId =
        widget.workItem?.categoryId ?? widget.initialCategoryId;
    _selectedTagIds = List.from(widget.workItem?.tagIds ?? []);
    _selectedPeopleIds = List.from(widget.workItem?.peopleIds ?? []);

    if (widget.workItem != null) {
      Future.microtask(() async {
        final existingValues = await ref.read(
            workItemAttributeValuesFamilyProvider(widget.workItem!.id).future);
        if (mounted) {
          setState(() {
            for (final v in existingValues) {
              if (v.textValue != null)
                _attributeValues[v.attributeDefinitionId] = v.textValue;
              if (v.numberValue != null)
                _attributeValues[v.attributeDefinitionId] = v.numberValue;
              if (v.booleanValue != null)
                _attributeValues[v.attributeDefinitionId] = v.booleanValue;
              if (v.dateValue != null)
                _attributeValues[v.attributeDefinitionId] = v.dateValue;
              if (v.optionId != null)
                _attributeValues[v.attributeDefinitionId] = v.optionId;
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Called after a nested SessionEditDialog closes. Tagging a new person
  /// on a session additively merges them into WorkItem.peopleIds, but this
  /// dialog's own _selectedPeopleIds is a local snapshot taken at open
  /// time - without this, hitting "Save Changes" here afterward would
  /// overwrite the just-merged people with that stale snapshot. Union
  /// (never remove) so it can't clobber an in-progress local edit either.
  Future<void> _refreshPeopleAfterSessionEdit() async {
    if (widget.workItem == null || !mounted) return;
    final latest =
        await ref.read(workItemRepositoryProvider).getById(widget.workItem!.id);
    if (latest == null || !mounted) return;
    setState(() {
      _selectedPeopleIds =
          {..._selectedPeopleIds, ...latest.peopleIds}.toList();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a project'),
            backgroundColor: AppTheme.accentRed),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a category'),
            backgroundColor: AppTheme.accentRed),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      WorkItem result;
      if (widget.workItem == null) {
        result = await ref.read(workItemsProvider.notifier).createWorkItem(
              name: _nameController.text.trim(),
              projectId: _selectedProjectId!,
              categoryId: _selectedCategoryId!,
              tagIds: _selectedTagIds,
              peopleIds: _selectedPeopleIds,
            );
      } else {
        result = await ref.read(workItemsProvider.notifier).updateWorkItem(
              widget.workItem!.copyWith(
                name: _nameController.text.trim(),
                projectId: _selectedProjectId!,
                categoryId: _selectedCategoryId!,
                tagIds: _selectedTagIds,
                peopleIds: _selectedPeopleIds,
              ),
            );
      }

      // Save attribute values for the task
      final definitions = ref.read(attributeDefinitionsProvider).value ?? [];
      final taskDefs = definitions
          .where((d) =>
              d.scope == AttributeScope.task && d.enabled && !d.isArchived)
          .toList();
      final valuesToSave = <WorkItemAttributeValue>[];
      final now = DateTime.now().toUtc();

      for (final entry in _attributeValues.entries) {
        final def = taskDefs.where((d) => d.id == entry.key).firstOrNull;
        if (def == null || entry.value == null) continue;

        String? textVal;
        double? numVal;
        bool? boolVal;
        DateTime? dateVal;
        String? optId;

        switch (def.type) {
          case AttributeType.text:
            textVal = entry.value.toString();
            break;
          case AttributeType.number:
            numVal = entry.value is num
                ? (entry.value as num).toDouble()
                : double.tryParse(entry.value.toString());
            break;
          case AttributeType.boolean:
            boolVal = entry.value == true;
            break;
          case AttributeType.singleSelect:
            optId = entry.value.toString();
            break;
          case AttributeType.multiSelect:
            textVal = (entry.value as List).join(',');
            break;
          case AttributeType.date:
            dateVal = entry.value is DateTime
                ? entry.value as DateTime
                : DateTime.tryParse(entry.value.toString());
            break;
        }

        valuesToSave.add(
          WorkItemAttributeValue(
            id: _uuid.v4(),
            workItemId: result.id,
            attributeDefinitionId: def.id,
            textValue: textVal,
            numberValue: numVal,
            booleanValue: boolVal,
            dateValue: dateVal,
            optionId: optId,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      if (valuesToSave.isNotEmpty) {
        await ref
            .read(workItemAttributeValuesControllerProvider)
            .saveValues(result.id, valuesToSave);
      }

      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save task: $e'),
              backgroundColor: AppTheme.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.workItem != null;
    final projectsAsync = ref.watch(projectsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final peopleAsync = ref.watch(peopleProvider);

    // Auto-select first project/category if none chosen yet and options are available
    projectsAsync.whenData((projects) {
      if (_selectedProjectId == null && projects.isNotEmpty) {
        _selectedProjectId = projects.first.id;
      }
    });

    categoriesAsync.whenData((categories) {
      if (_selectedCategoryId == null && categories.isNotEmpty) {
        _selectedCategoryId = categories.first.id;
      }
    });

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        backgroundColor: AppTheme.getColors(context).surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              BorderSide(color: AppTheme.getColors(context).divider, width: 1),
        ),
        titlePadding: EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: EdgeInsets.fromLTRB(24, 0, 24, 16),
        actionsPadding: EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check_box_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Text(
              isEditing ? 'Edit Work Item' : 'New Work Item',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getColors(context).textPrimary),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task Name
                  Text('Task Name',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.getColors(context).textSecondary)),
                  SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    style: TextStyle(
                        color: AppTheme.getColors(context).textPrimary,
                        fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Design auth flow, Write repository tests',
                      hintStyle: TextStyle(
                          color: AppTheme.getColors(context).textSecondary),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Task name is required';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  SizedBox(height: 16),

                  // Project & Category Dropdowns in a row
                  Row(
                    children: [
                      // Project Dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Project',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.getColors(context)
                                            .textSecondary)),
                                InkWell(
                                  onTap: () async {
                                    final p =
                                        await ProjectFormDialog.show(context);
                                    if (p != null)
                                      setState(() => _selectedProjectId = p.id);
                                  },
                                  child: Text('+ New',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            projectsAsync.when(
                              loading: () => SizedBox(
                                  height: 38,
                                  child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('Loading projects...',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.getColors(context)
                                                  .textSecondary)))),
                              error: (_, __) => Text('Error loading projects'),
                              data: (projects) {
                                return DropdownButtonFormField<String>(
                                  initialValue: projects.any(
                                          (p) => p.id == _selectedProjectId)
                                      ? _selectedProjectId
                                      : (projects.isNotEmpty
                                          ? projects.first.id
                                          : null),
                                  items: projects.map((p) {
                                    return DropdownMenuItem(
                                      value: p.id,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: ColorUtils.parseHex(
                                                  p.colorHex),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(p.name,
                                              overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedProjectId = val),
                                  decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8)),
                                  dropdownColor:
                                      AppTheme.getColors(context).surface,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),

                      // Category Dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Category',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.getColors(context)
                                            .textSecondary)),
                                InkWell(
                                  onTap: () async {
                                    final c =
                                        await CategoryFormDialog.show(context);
                                    if (c != null)
                                      setState(
                                          () => _selectedCategoryId = c.id);
                                  },
                                  child: Text('+ New',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            categoriesAsync.when(
                              loading: () => SizedBox(
                                  height: 38,
                                  child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('Loading categories...',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.getColors(context)
                                                  .textSecondary)))),
                              error: (_, __) =>
                                  Text('Error loading categories'),
                              data: (categories) {
                                return DropdownButtonFormField<String>(
                                  initialValue: categories.any(
                                          (c) => c.id == _selectedCategoryId)
                                      ? _selectedCategoryId
                                      : (categories.isNotEmpty
                                          ? categories.first.id
                                          : null),
                                  items: categories.map((c) {
                                    return DropdownMenuItem(
                                      value: c.id,
                                      child: Row(
                                        children: [
                                          Icon(IconUtils.getIcon(c.iconName),
                                              size: 14,
                                              color: AppTheme.primaryColor),
                                          SizedBox(width: 8),
                                          Text(c.name,
                                              overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedCategoryId = val),
                                  decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8)),
                                  dropdownColor:
                                      AppTheme.getColors(context).surface,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Tags Multi-select
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tags',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color:
                                  AppTheme.getColors(context).textSecondary)),
                      InkWell(
                        onTap: () async {
                          final t = await TagFormDialog.show(context);
                          if (t != null && !_selectedTagIds.contains(t.id)) {
                            setState(() => _selectedTagIds.add(t.id));
                          }
                        },
                        child: Text('+ New Tag',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  tagsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (tags) {
                      return SearchableMultiSelect(
                        allItems: tags
                            .map((tag) => SearchableMultiSelectItem(
                                  id: tag.id,
                                  label: tag.name,
                                  color: ColorUtils.parseHex(tag.colorHex),
                                ))
                            .toList(),
                        selectedIds: _selectedTagIds,
                        onChanged: (ids) =>
                            setState(() => _selectedTagIds = ids),
                        hintText: 'Search tags...',
                        emptyStateText: 'No tags created yet',
                      );
                    },
                  ),
                  SizedBox(height: 16),

                  // People Multi-select
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text('Assigned People',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color:
                                    AppTheme.getColors(context).textSecondary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      InkWell(
                        onTap: () async {
                          final p = await PersonFormDialog.show(context);
                          if (p != null && !_selectedPeopleIds.contains(p.id)) {
                            setState(() => _selectedPeopleIds.add(p.id));
                          }
                        },
                        child: Text('+ Add Person',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  peopleAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (people) {
                      return SearchableMultiSelect(
                        allItems: people
                            .map((person) => SearchableMultiSelectItem(
                                  id: person.id,
                                  label: person.name,
                                  icon: Icons.person,
                                ))
                            .toList(),
                        selectedIds: _selectedPeopleIds,
                        onChanged: (ids) =>
                            setState(() => _selectedPeopleIds = ids),
                        hintText: 'Search people...',
                        emptyStateText: 'No people added yet',
                      );
                    },
                  ),

                  if (widget.workItem != null) ...[
                    SizedBox(height: 16),
                    _SessionsSection(
                      workItem: widget.workItem!,
                      onSessionEdited: _refreshPeopleAfterSessionEdit,
                    ),
                  ],

                  // Custom Attribute Fields
                  Builder(
                    builder: (context) {
                      final definitions =
                          ref.watch(attributeDefinitionsProvider).value ?? [];
                      final taskDefs = definitions
                          .where((d) =>
                              d.scope == AttributeScope.task &&
                              d.enabled &&
                              !d.isArchived)
                          .toList();
                      if (taskDefs.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: DynamicAttributeFields(
                          definitions: taskDefs,
                          values: _attributeValues,
                          onValueChanged: (defId, val) {
                            setState(() {
                              _attributeValues[defId] = val;
                            });
                          },
                        ),
                      );
                    },
                  ),

                  // Notes - a read-only rollup of this task's session notes.
                  // Notes are now typed per-session (via SessionEditDialog);
                  // this just shows the history in one place.
                  Text('Notes',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.getColors(context).textSecondary)),
                  SizedBox(height: 6),
                  if (widget.workItem != null)
                    _TaskNotesRollup(
                      workItemId: widget.workItem!.id,
                      legacyNotes: widget.workItem!.notes,
                    )
                  else
                    Text(
                      'Notes will appear here once you log time on this task.',
                      style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.getColors(context).textSecondary),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: Text('Cancel',
                style: TextStyle(
                    color: AppTheme.getColors(context).textSecondary)),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: _isSubmitting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(isEditing ? 'Save Changes' : 'Create Task'),
          ),
        ],
      ),
    );
  }
}

/// Collapsed-by-default list of this task's past sessions. Kept collapsed
/// (and internally height-capped) so a task with a long history doesn't
/// dominate the already-dense edit dialog.
class _SessionsSection extends ConsumerStatefulWidget {
  final WorkItem workItem;
  final VoidCallback onSessionEdited;

  const _SessionsSection(
      {required this.workItem, required this.onSessionEdited});

  @override
  ConsumerState<_SessionsSection> createState() => _SessionsSectionState();
}

class _SessionsSectionState extends ConsumerState<_SessionsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sessionsAsync =
        ref.watch(sessionsForWorkItemProvider(widget.workItem.id));
    final count = sessionsAsync.value?.length ?? 0;
    final colors = AppTheme.getColors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Sessions ($count)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              border: Border.all(color: colors.divider),
              borderRadius: BorderRadius.circular(8),
            ),
            child: sessionsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Failed to load sessions',
                    style:
                        TextStyle(fontSize: 12, color: colors.textSecondary)),
              ),
              data: (sessions) {
                if (sessions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('No sessions logged yet',
                        style: TextStyle(
                            fontSize: 12, color: colors.textSecondary)),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: colors.divider),
                  itemBuilder: (context, index) {
                    return _SessionRow(
                      session: sessions[index],
                      workItem: widget.workItem,
                      onEdited: widget.onSessionEdited,
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  final Session session;
  final WorkItem workItem;
  final VoidCallback onEdited;

  const _SessionRow(
      {required this.session, required this.workItem, required this.onEdited});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.getColors(context);
    final dateFormat = DateFormat('MMM d, HH:mm');
    final start = session.startTime.toLocal();
    final end = session.endTime?.toLocal();
    final durationStr =
        TimerService.formatDuration(session.duration, compact: true);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          // SessionEditDialog only reads record.session / record.workItem.name
          // - the rest of SessionExportRecord's enrichment (project,
          // category, tags, people, idle periods) isn't rendered by it, so
          // a minimal record is enough to reopen the existing edit UI.
          final record = SessionExportRecord(
            session: session,
            workItem: workItem,
            grossDuration: session.duration,
            idleDuration: Duration.zero,
            netActiveDuration: session.duration,
          );
          await SessionEditDialog.show(context, record);
          onEdited();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      end != null
                          ? '${dateFormat.format(start)} - ${DateFormat('HH:mm').format(end)}'
                          : '${dateFormat.format(start)} - Running',
                      style: TextStyle(fontSize: 12, color: colors.textPrimary),
                    ),
                    if ((session.notes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        session.notes!,
                        style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                durationStr,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only rollup of a task's notes, built from its sessions' notes
/// (newest first, since sessionsForWorkItemProvider is already ordered
/// that way) rather than a single freeform field. Falls back to a
/// pre-existing WorkItem.notes value (from before this feature existed)
/// only when the task has no session notes yet - that legacy value is
/// never written to again.
class _TaskNotesRollup extends ConsumerWidget {
  final String workItemId;
  final String? legacyNotes;

  const _TaskNotesRollup({required this.workItemId, this.legacyNotes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsForWorkItemProvider(workItemId));
    final colors = AppTheme.getColors(context);

    return sessionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (sessions) {
        final dateFormat = DateFormat('MMM d, HH:mm');
        final noted =
            sessions.where((s) => (s.notes ?? '').trim().isNotEmpty).toList();

        if (noted.isEmpty) {
          if ((legacyNotes ?? '').trim().isNotEmpty) {
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Legacy note',
                      style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: colors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(legacyNotes!,
                      style:
                          TextStyle(fontSize: 13, color: colors.textPrimary)),
                ],
              ),
            );
          }
          return Text(
            'No notes yet - add notes while editing a session.',
            style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: colors.textSecondary),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: noted.map((s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateFormat.format(s.startTime.toLocal()),
                      style:
                          TextStyle(fontSize: 10, color: colors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(s.notes!,
                      style:
                          TextStyle(fontSize: 13, color: colors.textPrimary)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
