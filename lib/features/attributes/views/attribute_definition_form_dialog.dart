import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';

class AttributeDefinitionFormDialog extends ConsumerStatefulWidget {
  final AttributeDefinition? definition;

  const AttributeDefinitionFormDialog({super.key, this.definition});

  static Future<AttributeDefinition?> show(BuildContext context,
      {AttributeDefinition? definition}) {
    return showDialog<AttributeDefinition>(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          AttributeDefinitionFormDialog(definition: definition),
    );
  }

  @override
  ConsumerState<AttributeDefinitionFormDialog> createState() =>
      _AttributeDefinitionFormDialogState();
}

class _AttributeDefinitionFormDialogState
    extends ConsumerState<AttributeDefinitionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _keyController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late AttributeType _selectedType;
  late AttributeScope _selectedScope;
  late bool _required;
  late bool _searchable;
  late bool _reportable;
  late bool _showInQuickCapture;
  late bool _showInTaskDetails;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.definition;
    _keyController = TextEditingController(text: d?.key ?? '');
    _nameController = TextEditingController(text: d?.name ?? '');
    _descriptionController = TextEditingController(text: d?.description ?? '');
    _selectedType = d?.type ?? AttributeType.text;
    _selectedScope = d?.scope ?? AttributeScope.task;
    _required = d?.required ?? false;
    _searchable = d?.searchable ?? true;
    _reportable = d?.reportable ?? true;
    _showInQuickCapture = d?.showInQuickCapture ?? true;
    _showInTaskDetails = d?.showInTaskDetails ?? true;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatType(AttributeType type) {
    switch (type) {
      case AttributeType.text:
        return 'Text';
      case AttributeType.number:
        return 'Number';
      case AttributeType.boolean:
        return 'Boolean';
      case AttributeType.singleSelect:
        return 'Single Select';
      case AttributeType.multiSelect:
        return 'Multi Select';
      case AttributeType.date:
        return 'Date';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      if (widget.definition != null) {
        final updated = await ref
            .read(attributeDefinitionsProvider.notifier)
            .updateDefinition(
              widget.definition!.copyWith(
                key: _keyController.text.trim().toLowerCase(),
                name: _nameController.text.trim(),
                description: _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
                type: _selectedType,
                scope: _selectedScope,
                required: _required,
                searchable: _searchable,
                reportable: _reportable,
                showInQuickCapture: _showInQuickCapture,
                showInTaskDetails: _showInTaskDetails,
              ),
            );
        if (mounted) Navigator.of(context).pop(updated);
      } else {
        final created = await ref
            .read(attributeDefinitionsProvider.notifier)
            .createDefinition(
              key: _keyController.text.trim().toLowerCase(),
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              type: _selectedType,
              scope: _selectedScope,
              required: _required,
              searchable: _searchable,
              reportable: _reportable,
              showInQuickCapture: _showInQuickCapture,
              showInTaskDetails: _showInTaskDetails,
            );
        if (mounted) Navigator.of(context).pop(created);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving attribute: $e'),
              backgroundColor: AppTheme.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.definition != null;

    return AlertDialog(
      backgroundColor: AppTheme.getColors(context).surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.getColors(context).divider, width: 1),
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
            child:
                const Icon(Icons.tune, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            isEditing ? 'Edit Custom Attribute' : 'New Custom Attribute',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.getColors(context).textPrimary),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Attribute Name
                TextFormField(
                  controller: _nameController,
                  autofocus: !isEditing,
                  style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.getColors(context).textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Display Name *',
                    hintText: 'e.g. Jira Issue Key, Cost Centre, Client',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                  onChanged: (val) {
                    if (!isEditing && _keyController.text.isEmpty) {
                      _keyController.text = val
                          .trim()
                          .toLowerCase()
                          .replaceAll(RegExp(r'\s+'), '_')
                          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Key Identifier
                TextFormField(
                  controller: _keyController,
                  style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Courier',
                      color: AppTheme.getColors(context).textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Internal Key *',
                    hintText: 'e.g. jira_key, cost_centre',
                    helperText: 'Unique snake_case identifier',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Key is required';
                    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v.trim())) {
                      return 'Key must only contain lowercase letters, numbers, and underscores';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Type and Scope Row
                Row(
                  children: [
                    // Type Dropdown
                    Expanded(
                      child: DropdownButtonFormField<AttributeType>(
                        initialValue: _selectedType,
                        isDense: true,
                        isExpanded: true,
                        dropdownColor: AppTheme.getColors(context).surface,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.getColors(context).textPrimary),
                        decoration:
                            const InputDecoration(labelText: 'Data Type'),
                        items: AttributeType.values.map((t) {
                          return DropdownMenuItem(
                              value: t, child: Text(_formatType(t)));
                        }).toList(),
                        onChanged: isEditing
                            ? null
                            : (v) {
                                if (v != null) {
                                  setState(() => _selectedType = v);
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Scope Dropdown
                    Expanded(
                      child: DropdownButtonFormField<AttributeScope>(
                        initialValue: _selectedScope,
                        isDense: true,
                        isExpanded: true,
                        dropdownColor: AppTheme.getColors(context).surface,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.getColors(context).textPrimary),
                        decoration: const InputDecoration(labelText: 'Scope'),
                        items: const [
                          DropdownMenuItem(
                              value: AttributeScope.task,
                              child: Text('Task Scope')),
                          DropdownMenuItem(
                              value: AttributeScope.session,
                              child: Text('Session Scope')),
                        ],
                        onChanged: isEditing
                            ? null
                            : (v) {
                                if (v != null) {
                                  setState(() => _selectedScope = v);
                                }
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.getColors(context).textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Describe how this metadata field should be used',
                  ),
                ),
                const SizedBox(height: 16),

                Divider(color: AppTheme.getColors(context).divider),
                const SizedBox(height: 8),

                // Options Switches
                _buildSwitchRow(
                  title: 'Required Field',
                  subtitle: 'Must be provided when creating work items',
                  value: _required,
                  onChanged: (v) => setState(() => _required = v),
                ),
                const SizedBox(height: 8),
                _buildSwitchRow(
                  title: 'Show in Quick Capture',
                  subtitle: 'Display in the floating Quick Capture dialog',
                  value: _showInQuickCapture,
                  onChanged: (v) => setState(() => _showInQuickCapture = v),
                ),
                const SizedBox(height: 8),
                _buildSwitchRow(
                  title: 'Searchable',
                  subtitle:
                      'Include attribute value in global search filtering',
                  value: _searchable,
                  onChanged: (v) => setState(() => _searchable = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(isEditing ? 'Save Changes' : 'Create Attribute'),
        ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.getColors(context).textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.getColors(context).textSecondary)),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.85,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }
}
