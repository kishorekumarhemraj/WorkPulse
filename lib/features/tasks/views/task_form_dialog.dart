import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/attributes/widgets/dynamic_attribute_fields.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/categories/views/category_form_dialog.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/people/views/person_form_dialog.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/projects/views/project_form_dialog.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tags/views/tag_form_dialog.dart';
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
  late final TextEditingController _notesController;

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
    _notesController = TextEditingController(text: widget.workItem?.notes ?? '');

    _selectedProjectId = widget.workItem?.projectId ?? widget.initialProjectId;
    _selectedCategoryId = widget.workItem?.categoryId ?? widget.initialCategoryId;
    _selectedTagIds = List.from(widget.workItem?.tagIds ?? []);
    _selectedPeopleIds = List.from(widget.workItem?.peopleIds ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a project'), backgroundColor: AppTheme.accentRed),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category'), backgroundColor: AppTheme.accentRed),
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
              notes: _notesController.text.trim(),
              tagIds: _selectedTagIds,
              peopleIds: _selectedPeopleIds,
            );
      } else {
        result = await ref.read(workItemsProvider.notifier).updateWorkItem(
              widget.workItem!.copyWith(
                name: _nameController.text.trim(),
                projectId: _selectedProjectId!,
                categoryId: _selectedCategoryId!,
                notes: _notesController.text.trim(),
                tagIds: _selectedTagIds,
                peopleIds: _selectedPeopleIds,
              ),
            );
      }

      // Save attribute values for the task
      final definitions = ref.read(attributeDefinitionsProvider).value ?? [];
      final taskDefs = definitions.where((d) => d.scope == AttributeScope.task && d.enabled && !d.isArchived).toList();
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
            numVal = entry.value is num ? (entry.value as num).toDouble() : double.tryParse(entry.value.toString());
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
            dateVal = entry.value is DateTime ? entry.value as DateTime : DateTime.tryParse(entry.value.toString());
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
        await ref.read(workItemAttributeValuesFamilyProvider(result.id).notifier).saveValues(valuesToSave);
      }

      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save task: $e'), backgroundColor: AppTheme.accentRed),
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
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.dividerDark, width: 1),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_box_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isEditing ? 'Edit Work Item' : 'New Work Item',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
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
                  const Text('Task Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Design auth flow, Write repository tests',
                      hintStyle: TextStyle(color: AppTheme.textSecondaryDark),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Task name is required';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),

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
                                const Text('Project', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark)),
                                InkWell(
                                  onTap: () async {
                                    final p = await ProjectFormDialog.show(context);
                                    if (p != null) setState(() => _selectedProjectId = p.id);
                                  },
                                  child: const Text('+ New', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            projectsAsync.when(
                              loading: () => const SizedBox(height: 38, child: Align(alignment: Alignment.centerLeft, child: Text('Loading projects...', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark)))),
                              error: (_, __) => const Text('Error loading projects'),
                              data: (projects) {
                                return DropdownButtonFormField<String>(
                                  initialValue: projects.any((p) => p.id == _selectedProjectId) ? _selectedProjectId : (projects.isNotEmpty ? projects.first.id : null),
                                  items: projects.map((p) {
                                    return DropdownMenuItem(
                                      value: p.id,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: ColorUtils.parseHex(p.colorHex),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(p.name, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedProjectId = val),
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  dropdownColor: AppTheme.surfaceDark,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Category Dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark)),
                                InkWell(
                                  onTap: () async {
                                    final c = await CategoryFormDialog.show(context);
                                    if (c != null) setState(() => _selectedCategoryId = c.id);
                                  },
                                  child: const Text('+ New', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            categoriesAsync.when(
                              loading: () => const SizedBox(height: 38, child: Align(alignment: Alignment.centerLeft, child: Text('Loading categories...', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark)))),
                              error: (_, __) => const Text('Error loading categories'),
                              data: (categories) {
                                return DropdownButtonFormField<String>(
                                  initialValue: categories.any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : (categories.isNotEmpty ? categories.first.id : null),
                                  items: categories.map((c) {
                                    return DropdownMenuItem(
                                      value: c.id,
                                      child: Row(
                                        children: [
                                          Icon(IconUtils.getIcon(c.iconName), size: 14, color: AppTheme.primaryColor),
                                          const SizedBox(width: 8),
                                          Text(c.name, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  dropdownColor: AppTheme.surfaceDark,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tags Multi-select
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tags', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark)),
                      InkWell(
                        onTap: () async {
                          final t = await TagFormDialog.show(context);
                          if (t != null && !_selectedTagIds.contains(t.id)) {
                            setState(() => _selectedTagIds.add(t.id));
                          }
                        },
                        child: const Text('+ New Tag', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  tagsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (tags) {
                      if (tags.isEmpty) {
                        return const Text('No tags created yet', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark));
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: tags.map((tag) {
                          final isSelected = _selectedTagIds.contains(tag.id);
                          final color = ColorUtils.parseHex(tag.colorHex);
                          return FilterChip(
                            label: Text(tag.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedTagIds.add(tag.id);
                                } else {
                                  _selectedTagIds.remove(tag.id);
                                }
                              });
                            },
                            avatar: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            selectedColor: color.withValues(alpha: 0.3),
                            backgroundColor: AppTheme.cardDark,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : AppTheme.textSecondaryDark,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: isSelected ? color : AppTheme.dividerDark,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // People Multi-select
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text('Assigned People', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark), overflow: TextOverflow.ellipsis),
                      ),
                      InkWell(
                        onTap: () async {
                          final p = await PersonFormDialog.show(context);
                          if (p != null && !_selectedPeopleIds.contains(p.id)) {
                            setState(() => _selectedPeopleIds.add(p.id));
                          }
                        },
                        child: const Text('+ Add Person', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  peopleAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (people) {
                      if (people.isEmpty) {
                        return const Text('No people added yet', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark));
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: people.map((person) {
                          final isSelected = _selectedPeopleIds.contains(person.id);
                          return FilterChip(
                            label: Text(person.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedPeopleIds.add(person.id);
                                } else {
                                  _selectedPeopleIds.remove(person.id);
                                }
                              });
                            },
                            avatar: const Icon(Icons.person, size: 14),
                            selectedColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                            backgroundColor: AppTheme.cardDark,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : AppTheme.textSecondaryDark,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: isSelected ? AppTheme.primaryColor : AppTheme.dividerDark,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  // Custom Attribute Fields
                  Builder(
                    builder: (context) {
                      final definitions = ref.watch(attributeDefinitionsProvider).value ?? [];
                      final taskDefs = definitions.where((d) => d.scope == AttributeScope.task && d.enabled && !d.isArchived).toList();
                      if (taskDefs.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
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

                  // Notes
                  const Text('Notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Additional details, ticket links, context...',
                      hintStyle: TextStyle(color: AppTheme.textSecondaryDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryDark)),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isEditing ? 'Save Changes' : 'Create Task'),
          ),
        ],
      ),
    );
  }
}
