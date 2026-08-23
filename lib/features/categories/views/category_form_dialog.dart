import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
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
    _descController = TextEditingController(text: widget.category?.description ?? '');
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
        final created = await ref.read(categoriesProvider.notifier).createCategory(
              name: _nameController.text.trim(),
              description: _descController.text.trim(),
              iconName: _selectedIconName,
            );
        if (mounted) Navigator.of(context).pop(created);
      } else {
        final updated = await ref.read(categoriesProvider.notifier).updateCategory(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save category: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

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
        backgroundColor: AppTheme.getColors(context).surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.getColors(context).divider, width: 1),
        ),
        titlePadding: EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: EdgeInsets.fromLTRB(24, 0, 24, 20),
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
                IconUtils.getIcon(_selectedIconName),
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Text(
              isEditing ? 'Edit Category' : 'New Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.getColors(context).textPrimary),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Category Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.getColors(context).textSecondary)),
                  SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    style: TextStyle(color: AppTheme.getColors(context).textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Engineering, Architecture, Meetings',
                      hintStyle: TextStyle(color: AppTheme.getColors(context).textSecondary),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Category name is required';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  SizedBox(height: 16),
                  Text('Description (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.getColors(context).textSecondary)),
                  SizedBox(height: 6),
                  TextFormField(
                    controller: _descController,
                    maxLines: 2,
                    style: TextStyle(color: AppTheme.getColors(context).textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Brief summary of what belongs to this category...',
                      hintStyle: TextStyle(color: AppTheme.getColors(context).textSecondary),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('Select Icon', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.getColors(context).textSecondary)),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: IconUtils.availableIcons.entries.map((entry) {
                      final isSelected = entry.key == _selectedIconName;
                      return InkWell(
                        onTap: () => setState(() => _selectedIconName = entry.key),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.2) : AppTheme.getColors(context).card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : AppTheme.getColors(context).divider,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            entry.value,
                            size: 18,
                            color: isSelected ? AppTheme.primaryColor : AppTheme.getColors(context).textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isEditing ? 'Save Changes' : 'Create Category'),
          ),
        ],
      ),
    );
  }
}
