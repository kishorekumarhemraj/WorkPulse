import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/color_utils.dart';
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
    _selectedColorHex = widget.tag?.colorHex ?? ColorUtils.paletteHex[1]; // default green
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save tag: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.tag != null;

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
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ColorUtils.parseHex(_selectedColorHex).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.label_outline,
                color: ColorUtils.parseHex(_selectedColorHex),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isEditing ? 'Edit Tag' : 'New Tag',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tag Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Urgent, Bug, Release, Research',
                      hintStyle: TextStyle(color: AppTheme.textSecondaryDark),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Tag name is required';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Color Badge', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ColorUtils.paletteHex.map((hex) {
                      final isSelected = hex.toUpperCase() == _selectedColorHex.toUpperCase();
                      final color = ColorUtils.parseHex(hex);
                      return InkWell(
                        onTap: () => setState(() => _selectedColorHex = hex),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
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
                : Text(isEditing ? 'Save Changes' : 'Create Tag'),
          ),
        ],
      ),
    );
  }
}
