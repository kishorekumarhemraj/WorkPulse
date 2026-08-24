import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/widgets/app_snack_bar.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';

class CategoryFormDialog extends ConsumerStatefulWidget {
  final Category? category;

  const CategoryFormDialog({super.key, this.category});

  static Future<Category?> show(BuildContext context, {Category? category}) {
    return showDialog<Category>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CategoryFormDialog(category: category),
    );
  }

  @override
  ConsumerState<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late String _selectedIconName;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _descController =
        TextEditingController(text: widget.category?.description ?? '');
    _selectedIconName = widget.category?.iconName ?? 'folder';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      if (widget.category == null) {
        final created =
            await ref.read(categoriesProvider.notifier).createCategory(
                  name: _nameController.text.trim(),
                  description: _descController.text.trim(),
                  iconName: _selectedIconName,
                );
        if (mounted) Navigator.of(context).pop(created);
      } else {
        final updated =
            await ref.read(categoriesProvider.notifier).updateCategory(
                  widget.category!.copyWith(
                    name: _nameController.text.trim(),
                    description: _descController.text.trim(),
                    iconName: _selectedIconName,
                  ),
                );
        if (mounted) Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar.failure(message: 'Failed to save category: $e'),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return AppDialog(
      title: isEditing ? 'Edit Category' : 'New Category',
      icon: IconUtils.getIcon(_selectedIconName),
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
              : Text(isEditing ? 'Save Changes' : 'Create Category'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogField(
              label: 'Category Name',
              required: true,
              child: TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g. Engineering, Meetings, Support',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Category name is required';
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
                  hintText: 'What kind of work belongs in this category?',
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            DialogField(
              label: 'Icon Badge',
              child: _IconPicker(
                selected: _selectedIconName,
                onChanged: (name) => setState(() => _selectedIconName = name),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _IconPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final entry in IconUtils.availableIcons.entries)
          () {
            final isSelected = entry.key == selected;
            return Semantics(
              label: entry.key,
              selected: isSelected,
              inMutuallyExclusiveGroup: true,
              button: true,
              child: Tooltip(
                message: entry.key,
                child: InkWell(
                  onTap: () => onChanged(entry.key),
                  borderRadius: Radii.mdAll,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected ? colors.accentSubtle : colors.card,
                      borderRadius: Radii.mdAll,
                      border: Border.all(
                        color: isSelected ? colors.accent : colors.divider,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      entry.value,
                      size: IconSizes.lg,
                      color: isSelected ? colors.accent : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }
}
