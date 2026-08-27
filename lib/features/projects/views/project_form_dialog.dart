import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/widgets/app_snack_bar.dart';
import 'package:workpulse/core/widgets/color_swatch_picker.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';

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
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _descController =
        TextEditingController(text: widget.project?.description ?? '');
    _codeController =
        TextEditingController(text: widget.project?.timesheetCode ?? '');
    _selectedColorHex = widget.project?.colorHex ?? ColorUtils.paletteHex.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      if (widget.project == null) {
        final created = await ref.read(projectsProvider.notifier).createProject(
              name: _nameController.text.trim(),
              description: _descController.text.trim(),
              colorHex: _selectedColorHex,
              timesheetCode: _codeController.text.trim(),
            );
        if (mounted) Navigator.of(context).pop(created);
      } else {
        final updated = await ref.read(projectsProvider.notifier).updateProject(
              widget.project!.copyWith(
                name: _nameController.text.trim(),
                description: _descController.text.trim(),
                colorHex: _selectedColorHex,
                timesheetCode: _codeController.text.trim(),
              ),
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
    if (code.isEmpty) return 'Timesheet code is required';

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
              label: 'Timesheet Code',
              required: true,
              helperText: 'The code this project is booked against in your '
                  'timesheet system. Shown beside the project on the Time '
                  'Sheet so the hours can be transcribed without looking it '
                  'up.',
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
