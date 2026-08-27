import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/widgets/app_snack_bar.dart';
import 'package:workpulse/core/widgets/color_swatch_picker.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/project_timesheet_code.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';

const _uuid = Uuid();

class ProjectFormDialog extends ConsumerStatefulWidget {
  final Project? project;

  const ProjectFormDialog({super.key, this.project});

  static Future<Project?> show(BuildContext context, {Project? project}) {
    return showDialog<Project>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ProjectFormDialog(project: project),
    );
  }

  @override
  ConsumerState<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends ConsumerState<ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _codeController;
  late String _selectedColorHex;
  String? _selectedDiscriminatorId;
  bool _isSubmitting = false;

  List<AttributeOption> _loadedOptions = [];
  final Map<String, TextEditingController> _optionCodeControllers = {};
  final Map<String, String> _existingCodeIds = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _descController =
        TextEditingController(text: widget.project?.description ?? '');
    _codeController =
        TextEditingController(text: widget.project?.timesheetCode ?? '');
    _selectedColorHex = widget.project?.colorHex ?? ColorUtils.paletteHex.first;
    _selectedDiscriminatorId = widget.project?.codeAttributeDefinitionId;

    _loadInitialTimesheetCodes();
  }

  Future<void> _loadInitialTimesheetCodes() async {
    if (widget.project != null) {
      final existingCodes = await ref
          .read(projectRepositoryProvider)
          .getTimesheetCodes(widget.project!.id);
      for (final c in existingCodes) {
        _existingCodeIds[c.attributeOptionId] = c.id;
        _optionCodeControllers[c.attributeOptionId] =
            TextEditingController(text: c.code);
      }
    }

    if (_selectedDiscriminatorId != null) {
      await _loadOptionsForDefinition(_selectedDiscriminatorId!);
    }
  }

  Future<void> _loadOptionsForDefinition(String defId) async {
    final options = await ref
        .read(attributeRepositoryProvider)
        .getOptions(defId, includeArchived: true);
    for (final opt in options) {
      _optionCodeControllers.putIfAbsent(
        opt.id,
        () => TextEditingController(),
      );
    }
    if (mounted) {
      setState(() {
        _loadedOptions = options;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _codeController.dispose();
    for (final controller in _optionCodeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final now = DateTime.now().toUtc();
      final List<ProjectTimesheetCode> timesheetCodes = [];

      if (_selectedDiscriminatorId != null) {
        for (final entry in _optionCodeControllers.entries) {
          final code = entry.value.text.trim();
          if (code.isNotEmpty) {
            timesheetCodes.add(
              ProjectTimesheetCode(
                id: _existingCodeIds[entry.key] ?? _uuid.v4(),
                projectId: widget.project?.id ?? '',
                attributeOptionId: entry.key,
                code: code,
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        }
      }

      if (widget.project == null) {
        final created = await ref.read(projectsProvider.notifier).createProject(
              name: _nameController.text.trim(),
              description: _descController.text.trim(),
              colorHex: _selectedColorHex,
              timesheetCode: _codeController.text.trim(),
              codeAttributeDefinitionId: _selectedDiscriminatorId,
              timesheetCodes: timesheetCodes,
            );
        if (mounted) Navigator.of(context).pop(created);
      } else {
        final updated = await ref.read(projectsProvider.notifier).updateProject(
              widget.project!.copyWith(
                name: _nameController.text.trim(),
                description: _descController.text.trim(),
                colorHex: _selectedColorHex,
                timesheetCode: _codeController.text.trim(),
                codeAttributeDefinitionId: _selectedDiscriminatorId,
              ),
              timesheetCodes: timesheetCodes,
            );
        if (mounted) Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar.failure(message: 'Failed to save project: $e'),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// A code has to be present and has to be this project's alone — two
  /// projects sharing one would book their hours to the same line, which is
  /// precisely the error this screen exists to prevent.
  String? _validateTimesheetCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) return 'Default timesheet code is required';

    final needle = code.toLowerCase();
    final clash = (ref.read(projectsProvider).value ?? [])
        .where((p) => p.id != widget.project?.id)
        .where((p) => p.timesheetCode?.trim().toLowerCase() == needle)
        .firstOrNull;

    if (clash != null) return 'Already used by "${clash.name}"';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.project != null;
    final colors = context.colors;
    final theme = Theme.of(context);

    final allDefsAsync = ref.watch(attributeDefinitionsProvider);
    final allDefs = allDefsAsync.value ?? [];
    // Single-select task-scoped attributes only (F10)
    final candidateDefs = allDefs.where((d) =>
        d.scope == AttributeScope.task &&
        d.type == AttributeType.singleSelect &&
        !d.isArchived &&
        d.enabled).toList();

    final activeOptions =
        _loadedOptions.where((o) => !o.isArchived).toList();
    final retiredOptionsWithMapping = _loadedOptions
        .where((o) =>
            o.isArchived &&
            (_optionCodeControllers[o.id]?.text.trim().isNotEmpty ?? false))
        .toList();

    return AppDialog(
      title: isEditing ? 'Edit Project' : 'New Project',
      icon: Icons.folder_outlined,
      iconColor: ColorUtils.parseHex(_selectedColorHex),
      onSubmit: _isSubmitting ? null : _submit,
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isEditing ? 'Save Changes' : 'Create Project'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogField(
              label: 'Project Name',
              required: true,
              child: TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g. WorkPulse App, Client Portal',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Project name is required';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            DialogField(
              label: 'Description (Optional)',
              child: TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Brief description of the project…',
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            DialogField(
              label: 'Default Timesheet Code',
              required: true,
              helperText: 'The fallback code booked when tasks have no '
                  'specific option set, or when the project has a single '
                  'code.',
              child: TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'e.g. PRJ-1042, CC-7781, WBS.4.2',
                ),
                validator: _validateTimesheetCode,
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            DialogField(
              label: 'Code Varies By',
              helperText:
                  'Select a single-select task attribute if this project has '
                  'different codes for different streams or releases.',
              child: DropdownButtonFormField<String?>(
                value: candidateDefs
                        .any((d) => d.id == _selectedDiscriminatorId)
                    ? _selectedDiscriminatorId
                    : null,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.sm,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Doesn't vary (single code)"),
                  ),
                  for (final def in candidateDefs)
                    DropdownMenuItem<String?>(
                      value: def.id,
                      child: Text(def.name),
                    ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedDiscriminatorId = val;
                  });
                  if (val != null) {
                    _loadOptionsForDefinition(val);
                  }
                },
              ),
            ),
            if (_selectedDiscriminatorId != null &&
                activeOptions.isNotEmpty) ...[
              const SizedBox(height: Spacing.lg),
              Text(
                'Timesheet Codes by Option',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'Leave blank to fall back to the project default code.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              for (final opt in activeOptions) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sm),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          opt.label,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _optionCodeControllers.putIfAbsent(
                            opt.id,
                            () => TextEditingController(),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'e.g. PRJ-${opt.label}',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: Spacing.sm,
                              vertical: Spacing.sm,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            if (_selectedDiscriminatorId != null &&
                retiredOptionsWithMapping.isNotEmpty) ...[
              const SizedBox(height: Spacing.sm),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Retired Options (${retiredOptionsWithMapping.length})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: [
                    for (final opt in retiredOptionsWithMapping)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.sm),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 140,
                              child: Text(
                                '${opt.label} (Retired)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.textTertiary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: Spacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: _optionCodeControllers[opt.id],
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: Spacing.sm,
                                    vertical: Spacing.sm,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            DialogField(
              label: 'Color Badge',
              helperText:
                  'Used to identify this project across lists, charts and the '
                  'active timer bar.',
              child: ColorSwatchPicker(
                selectedHex: _selectedColorHex,
                onChanged: (hex) => setState(() => _selectedColorHex = hex),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

