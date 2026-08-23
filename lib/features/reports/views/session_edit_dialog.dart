import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/attributes/widgets/dynamic_attribute_fields.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';

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
  final _formKey = GlobalKey<FormState>();
  late DateTime _startTime;
  late DateTime? _endTime;
  late final TextEditingController _notesController;
  final Map<String, dynamic> _sessionAttributeValues = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final s = widget.record.session;
    _startTime = s.startTime.toLocal();
    _endTime = s.endTime?.toLocal();
    _notesController = TextEditingController(text: widget.record.workItem.notes ?? '');
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
      _startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
      _endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    if (_endTime != null && _endTime!.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time cannot be before start time'), backgroundColor: AppTheme.accentRed),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(sessionEditorControllerProvider).updateSession(
            sessionId: widget.record.session.id,
            startTime: _startTime.toUtc(),
            endTime: _endTime?.toUtc(),
            notes: _notesController.text.trim(),
            attributeValues: _sessionAttributeValues,
          );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update session: $e'), backgroundColor: AppTheme.accentRed),
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
    final sessionDefs = definitions.where((d) => d.scope == AttributeScope.session && d.enabled && !d.isArchived).toList();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.dividerDark),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.edit_calendar, size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Session',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
                          ),
                          Text(
                            widget.record.workItem.name,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondaryDark),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Start Time Field
                        const Text('Start Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryDark)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickStartTime,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.dividerDark),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: AppTheme.primaryColor),
                                const SizedBox(width: 10),
                                Text(dateFormat.format(_startTime), style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryDark)),
                                const Spacer(),
                                const Text('Change', style: TextStyle(fontSize: 11, color: AppTheme.primaryColor)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // End Time Field
                        const Text('End Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryDark)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickEndTime,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.dividerDark),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.accentGreen),
                                const SizedBox(width: 10),
                                Text(
                                  _endTime != null ? dateFormat.format(_endTime!) : 'In Progress',
                                  style: TextStyle(fontSize: 13, color: _endTime != null ? AppTheme.textPrimaryDark : AppTheme.accentGreen),
                                ),
                                const Spacer(),
                                const Text('Change', style: TextStyle(fontSize: 11, color: AppTheme.primaryColor)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Session Notes
                        const Text('Session Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryDark)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryDark),
                          decoration: InputDecoration(
                            hintText: 'What did you work on during this block?',
                            hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                            filled: true,
                            fillColor: AppTheme.cardDark,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.dividerDark)),
                          ),
                        ),

                        // Custom Session Attributes
                        if (sessionDefs.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Divider(color: AppTheme.dividerDark),
                          const SizedBox(height: 10),
                          const Text('Session Custom Attributes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark)),
                          const SizedBox(height: 12),
                          DynamicAttributeFields(
                            definitions: sessionDefs,
                            values: _sessionAttributeValues,
                            onValueChanged: (String id, dynamic val) => _sessionAttributeValues[id] = val,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Footer Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryDark)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
