import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
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
  late final TextEditingController _teamController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.person?.name ?? '');
    _emailController = TextEditingController(text: widget.person?.email ?? '');
    _teamController = TextEditingController(text: widget.person?.team ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _teamController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final teamVal = _teamController.text.trim().isEmpty
          ? null
          : _teamController.text.trim();
      final emailVal = _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim();

      if (widget.person == null) {
        final created = await ref.read(peopleProvider.notifier).createPerson(
              name: _nameController.text.trim(),
              email: emailVal,
              team: teamVal,
            );
        if (mounted) Navigator.of(context).pop(created);
      } else {
        final updated = await ref.read(peopleProvider.notifier).updatePerson(
              widget.person!.copyWith(
                name: _nameController.text.trim(),
                email: emailVal,
                team: teamVal,
                clearEmail: emailVal == null,
                clearTeam: teamVal == null,
              ),
            );
        if (mounted) Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save person: $e'),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.person != null;

    return AppDialog(
      title: isEditing ? 'Edit Person' : 'New Person',
      icon: Icons.person_outline,
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
              : Text(isEditing ? 'Save Changes' : 'Create Person'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogField(
              label: 'Name',
              required: true,
              child: TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g. John Doe, Alice Smith',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            DialogField(
              label: 'Team / Department (Optional)',
              child: TextFormField(
                controller: _teamController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Frontend, Product, Design, QA',
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            DialogField(
              label: 'Email Address (Optional)',
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'e.g. john@company.com',
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final emailRegExp =
                        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegExp.hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
