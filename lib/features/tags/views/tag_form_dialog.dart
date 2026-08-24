import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/widgets/app_snack_bar.dart';
import 'package:workpulse/core/widgets/color_swatch_picker.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';

class TagFormDialog extends ConsumerStatefulWidget {
  final Tag? tag;

  const TagFormDialog({super.key, this.tag});

  static Future<Tag?> show(BuildContext context, {Tag? tag}) {
    return showDialog<Tag>(
      context: context,
      barrierDismissible: true,
      builder: (context) => TagFormDialog(tag: tag),
    );
  }

  @override
  ConsumerState<TagFormDialog> createState() => _TagFormDialogState();
}

class _TagFormDialogState extends ConsumerState<TagFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedColorHex;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tag?.name ?? '');
    _selectedColorHex =
        widget.tag?.colorHex ?? ColorUtils.paletteHex[1]; // default green
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      if (widget.tag == null) {
        final created = await ref.read(tagsProvider.notifier).createTag(
              name: _nameController.text.trim(),
              colorHex: _selectedColorHex,
            );
        if (mounted) Navigator.of(context).pop(created);
      } else {
        final updated = await ref.read(tagsProvider.notifier).updateTag(
              widget.tag!.copyWith(
                name: _nameController.text.trim(),
                colorHex: _selectedColorHex,
              ),
            );
        if (mounted) Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar.failure(message: 'Failed to save tag: $e'),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.tag != null;

    return AppDialog(
      title: isEditing ? 'Edit Tag' : 'New Tag',
      icon: Icons.label_outline,
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
              : Text(isEditing ? 'Save Changes' : 'Create Tag'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogField(
              label: 'Tag Name',
              required: true,
              child: TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g. urgent, billable, blocked',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Tag name is required';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            DialogField(
              label: 'Color',
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
