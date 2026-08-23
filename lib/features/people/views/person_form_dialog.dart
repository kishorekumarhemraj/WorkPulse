import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';

class PersonFormDialog extends ConsumerStatefulWidget {
  final Person? person;

  const PersonFormDialog({super.key, this.person});

  static Future<Person?> show(BuildContext context, {Person? person}) {
    return showDialog<Person>(
      context: context,
      barrierDismissible: true,
      builder: (context) => PersonFormDialog(person: person),
    );
  }

  @override
  ConsumerState<PersonFormDialog> createState() => _PersonFormDialogState();
}

class _PersonFormDialogState extends ConsumerState<PersonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.person?.name ?? '');
    _emailController = TextEditingController(text: widget.person?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      if (widget.person == null) {
        final created = await ref.read(peopleProvider.notifier).createPerson(
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
            );
        if (mounted) Navigator.of(context).pop(created);
      } else {
        final updated = await ref.read(peopleProvider.notifier).updatePerson(
              widget.person!.copyWith(
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
              ),
            );
        if (mounted) Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save person: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.person != null;

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
                Icons.person_outline,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Text(
              isEditing ? 'Edit Person' : 'New Person',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.getColors(context).textPrimary),
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
                  Text('Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.getColors(context).textSecondary)),
                  SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    style: TextStyle(color: AppTheme.getColors(context).textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. John Doe, Alice Smith',
                      hintStyle: TextStyle(color: AppTheme.getColors(context).textSecondary),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  SizedBox(height: 16),
                  Text('Email Address (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.getColors(context).textSecondary)),
                  SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: AppTheme.getColors(context).textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. john@company.com',
                      hintStyle: TextStyle(color: AppTheme.getColors(context).textSecondary),
                    ),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegExp.hasMatch(value.trim())) {
                          return 'Please enter a valid email address';
                        }
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
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
                : Text(isEditing ? 'Save Changes' : 'Add Person'),
          ),
        ],
      ),
    );
  }
}
