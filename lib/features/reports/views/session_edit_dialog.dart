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
    _notesController =
        TextEditingController(text: widget.record.workItem.notes ?? '');
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
      _startTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
      _endTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    if (_endTime != null && _endTime!.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('End time cannot be before start time'),
            backgroundColor: AppTheme.accentRed),
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
          SnackBar(
              content: Text('Failed to update session: $e'),
              backgroundColor: AppTheme.accentRed),
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
    final sessionDefs = definitions
        .where((d) =>
            d.scope == AttributeScope.session && d.enabled && !d.isArchived)
        .toList();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Dialog(
      backgroundColor: AppTheme.getColors(context).surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.getColors(context).divider),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.edit_calendar,
                        size: 20, color: AppTheme.primaryColor),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Session',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.getColors(context).textPrimary),
                          ),
                          Text(
                            widget.record.workItem.name,
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    AppTheme.getColors(context).textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          size: 18,
                          color: AppTheme.getColors(context).textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Start Time Field
                        Text('Start Time',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    AppTheme.getColors(context).textSecondary)),
                        SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.getColors(context).divider),
                          ),
                          child: Material(
                            color: AppTheme.getColors(context).card,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: _pickStartTime,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time,
                                        size: 16, color: AppTheme.primaryColor),
                                    SizedBox(width: 10),
                                    Text(dateFormat.format(_startTime),
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.getColors(context)
                                                .textPrimary)),
                                    const Spacer(),
                                    Text('Change',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.primaryColor)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),

                        // End Time Field
                        Text('End Time',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    AppTheme.getColors(context).textSecondary)),
                        SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.getColors(context).divider),
                          ),
                          child: Material(
                            color: AppTheme.getColors(context).card,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: _pickEndTime,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        size: 16, color: AppTheme.accentGreen),
                                    SizedBox(width: 10),
                                    Text(
                                      _endTime != null
                                          ? dateFormat.format(_endTime!)
                                          : 'In Progress',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: _endTime != null
                                              ? AppTheme.getColors(context)
                                                  .textPrimary
                                              : AppTheme.accentGreen),
                                    ),
                                    const Spacer(),
                                    Text('Change',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.primaryColor)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),

                        // Session Notes
                        Text('Session Notes',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    AppTheme.getColors(context).textSecondary)),
                        SizedBox(height: 6),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.getColors(context).textPrimary),
                          decoration: InputDecoration(
                            hintText: 'What did you work on during this block?',
                            hintStyle: TextStyle(
                                fontSize: 12,
                                color:
                                    AppTheme.getColors(context).textSecondary),
                            filled: true,
                            fillColor: AppTheme.getColors(context).card,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color:
                                        AppTheme.getColors(context).divider)),
                          ),
                        ),

                        // Custom Session Attributes
                        if (sessionDefs.isNotEmpty) ...[
                          SizedBox(height: 20),
                          Divider(color: AppTheme.getColors(context).divider),
                          SizedBox(height: 10),
                          Text('Session Custom Attributes',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      AppTheme.getColors(context).textPrimary)),
                          SizedBox(height: 12),
                          DynamicAttributeFields(
                            definitions: sessionDefs,
                            values: _sessionAttributeValues,
                            onValueChanged: (String id, dynamic val) =>
                                _sessionAttributeValues[id] = val,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Footer Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel',
                          style: TextStyle(
                              color:
                                  AppTheme.getColors(context).textSecondary)),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('Save Changes'),
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
