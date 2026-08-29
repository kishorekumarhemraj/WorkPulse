import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/theme/classification_style.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/core/widgets/app_select.dart';
import 'package:workpulse/core/widgets/app_snack_bar.dart';
import 'package:workpulse/core/widgets/searchable_multi_select.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/attributes/widgets/dynamic_attribute_fields.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';

class SessionEditDialog extends ConsumerStatefulWidget {
  final SessionExportRecord record;

  const SessionEditDialog({super.key, required this.record});

  static Future<void> show(BuildContext context, SessionExportRecord record) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SessionEditDialog(record: record),
    );
  }

  @override
  ConsumerState<SessionEditDialog> createState() => _SessionEditDialogState();
}

class _SessionEditDialogState extends ConsumerState<SessionEditDialog> {
  /// Roughly a paragraph: tall enough to write in, capped so a long note
  /// scrolls inside the field instead of pushing Save off the dialog.
  static const int _notesMinLines = 5;
  static const int _notesMaxLines = 8;

  final _formKey = GlobalKey<FormState>();
  late DateTime _startTime;
  late DateTime? _endTime;
  late String? _selectedCategoryId;

  /// Null means "inherit from the task" — the normal case, and the reason
  /// this is a nullable override rather than a plain field.
  late FinancialClassification? _classificationOverride;
  late final TextEditingController _notesController;
  late List<String> _selectedTagIds;
  late List<String> _selectedPeopleIds;
  final Map<String, dynamic> _sessionAttributeValues = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final s = widget.record.session;
    _startTime = s.startTime.toLocal();
    _endTime = s.endTime?.toLocal();
    // The session's own values, not the work item's. Pre-filling from the work
    // item made an unclassified session look classified, and saving the form
    // silently wrote those borrowed values onto it.
    _selectedCategoryId = s.categoryId;
    _classificationOverride = s.financialClassification;
    _notesController = TextEditingController(text: s.notes ?? '');
    _selectedTagIds = List.from(s.tagIds);
    _selectedPeopleIds = List.from(s.peopleIds);

    Future.microtask(() async {
      try {
        final existingValues = await ref.read(
            sessionAttributeValuesFamilyProvider(widget.record.session.id)
                .future);
        if (mounted) {
          setState(() {
            for (final v in existingValues) {
              if (v.textValue != null) {
                _sessionAttributeValues[v.attributeDefinitionId] = v.textValue;
              }
              if (v.numberValue != null) {
                _sessionAttributeValues[v.attributeDefinitionId] =
                    v.numberValue;
              }
              if (v.booleanValue != null) {
                _sessionAttributeValues[v.attributeDefinitionId] =
                    v.booleanValue;
              }
              if (v.dateValue != null) {
                _sessionAttributeValues[v.attributeDefinitionId] = v.dateValue;
              }
              if (v.optionId != null) {
                _sessionAttributeValues[v.attributeDefinitionId] = v.optionId;
              }
            }
          });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      _startTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickEndTime() async {
    final base = _endTime ?? _startTime;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;

    setState(() {
      _endTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    if (_endTime != null && _endTime!.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const AppSnackBar.failure(
          message: 'End time cannot be before start time',
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final trimmedNotes = _notesController.text.trim();
      await ref.read(sessionEditorControllerProvider).updateSession(
            sessionId: widget.record.session.id,
            startTime: _startTime.toUtc(),
            endTime: _endTime?.toUtc(),
            categoryId: _selectedCategoryId,
            financialClassification: _classificationOverride,
            clearFinancialClassification: _classificationOverride == null,
            notes: trimmedNotes.isEmpty ? null : trimmedNotes,
            clearNotes: trimmedNotes.isEmpty,
            tagIds: _selectedTagIds,
            peopleIds: _selectedPeopleIds,
            attributeValues: _sessionAttributeValues,
          );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar.failure(message: 'Failed to update session: $e'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final definitions = ref.watch(attributeDefinitionsProvider).value ?? [];
    final sessionDefs = definitions
        .where((d) =>
            d.scope == AttributeScope.session && d.enabled && !d.isArchived)
        .toList();
    final categoriesAsync = ref.watch(categoriesProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final peopleAsync = ref.watch(peopleProvider);
    final colors = context.colors;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    // What this session would report if it stated nothing of its own. Shown
    // on the control so the override reads as a departure from something,
    // rather than as the only classification in play.
    final taskName = widget.record.workItem.name;
    final inherited = widget.record.workItem.financialClassification;
    final inheritedLabel = inherited.label;

    return AppDialog(
      title: 'Edit Session',
      subtitle: widget.record.workItem.name,
      icon: Icons.edit_calendar,
      width: DialogWidth.medium,
      onSubmit: _isSubmitting ? null : _submit,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onAccent,
                  ),
                )
              : const Text('Save Changes'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The order a session is actually reviewed in: when it ran,
            // what kind of work it was, how it books to the timesheet, who
            // was there, and only then the free text. Notes sat in the middle
            // before, which put the one field with no fixed shape between two
            // that have one.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DialogField(
                    label: 'Start Time',
                    child: _TimeField(
                      icon: Icons.access_time,
                      iconColor: colors.accent,
                      value: dateFormat.format(_startTime),
                      onTap: _pickStartTime,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: DialogField(
                    label: 'End Time',
                    child: _TimeField(
                      icon: Icons.check_circle_outline,
                      iconColor: colors.success,
                      value: _endTime != null
                          ? dateFormat.format(_endTime!)
                          : 'In Progress',
                      valueColor: _endTime == null ? colors.success : null,
                      onTap: _pickEndTime,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            DialogField(
              label: 'Category',
              child: categoriesAsync.when(
                loading: () => const AppSelectPlaceholder(
                  label: 'Loading categories…',
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (categories) {
                  return AppSelect<String?>(
                    placeholder: 'No Category',
                    value: _selectedCategoryId,
                    maxTriggerWidth: double.infinity,
                    options: [
                      const SelectOption<String?>(
                        value: null,
                        label: 'No Category',
                        icon: Icons.label_off_outlined,
                      ),
                      ...categories.map(
                        (c) => SelectOption<String?>(
                          value: c.id,
                          label: c.name,
                          icon: IconUtils.getIcon(c.iconName),
                        ),
                      ),
                    ],
                    onChanged: (catId) {
                      setState(() => _selectedCategoryId = catId);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: Spacing.lg),
            DialogField(
              label: timeSheetClassificationLabel,
              helperText: _classificationOverride == null
                  ? 'Following "$taskName", which is $inheritedLabel.'
                  : 'Overriding "$taskName", which is $inheritedLabel. '
                      'Inherit again to follow the work item.',
              child: AppSelect<FinancialClassification?>(
                placeholder: 'Inherit from work item',
                value: _classificationOverride,
                maxTriggerWidth: double.infinity,
                options: [
                  SelectOption<FinancialClassification?>(
                    value: null,
                    label: 'Inherit — $inheritedLabel',
                    icon: Icons.subdirectory_arrow_right,
                  ),
                  for (final option in FinancialClassification.values)
                    SelectOption<FinancialClassification?>(
                      value: option,
                      label: 'Override — ${option.label}',
                      icon: option.icon,
                    ),
                ],
                onChanged: (value) {
                  setState(() => _classificationOverride = value);
                },
              ),
            ),
            const SizedBox(height: Spacing.lg),
            DialogField(
              label: 'People',
              child: peopleAsync.when(
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
                    hintText: 'Search people…',
                    emptyStateText: 'No people added yet',
                  );
                },
              ),
            ),
            const SizedBox(height: Spacing.lg),
            DialogField(
              label: 'Tags',
              child: tagsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (tags) {
                  return SearchableMultiSelect(
                    allItems: tags
                        .map((tag) => SearchableMultiSelectItem(
                              id: tag.id,
                              label: '#${tag.name}',
                              icon: Icons.label_outline,
                              color: ColorUtils.parseHex(tag.colorHex),
                            ))
                        .toList(),
                    selectedIds: _selectedTagIds,
                    onChanged: (ids) => setState(() => _selectedTagIds = ids),
                    hintText: 'Search tags…',
                    emptyStateText: 'No tags added yet',
                  );
                },
              ),
            ),
            const SizedBox(height: Spacing.lg),
            DialogField(
              label: 'Session Notes',
              child: TextFormField(
                controller: _notesController,
                // Two lines was a slot, not a place to write. What actually
                // gets typed here is a couple of sentences about what the
                // block was for, and it should be readable without scrolling
                // a field the size of a search box.
                minLines: _notesMinLines,
                maxLines: _notesMaxLines,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'What did you work on during this block?',
                ),
              ),
            ),
            if (sessionDefs.isNotEmpty) ...[
              const SizedBox(height: Spacing.xl),
              DialogSection(
                title: 'Session Custom Attributes',
                icon: Icons.tune,
                child: DynamicAttributeFields(
                  definitions: sessionDefs,
                  values: _sessionAttributeValues,
                  onValueChanged: (String id, dynamic val) =>
                      _sessionAttributeValues[id] = val,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A read-only field that opens a date/time picker when tapped.
class _TimeField extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final Color? valueColor;
  final VoidCallback onTap;

  const _TimeField({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.onTap,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.field,
      borderRadius: Radii.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.mdAll,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: Radii.mdAll,
            border: Border.all(color: colors.divider),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm + 2,
          ),
          child: Row(
            children: [
              Icon(icon, size: IconSizes.md, color: iconColor),
              const SizedBox(width: Spacing.sm + 2),
              Expanded(
                child: Text(
                  value,
                  style: AppTypography.numeric(
                    fontSize: 13,
                    color: valueColor ?? colors.textPrimary,
                  ),
                ),
              ),
              Text(
                'Change',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
