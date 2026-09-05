import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/features/settings/providers/app_settings_provider.dart';

/// Configures notification rules, digest time, quiet hours and weekend delivery.
class ReminderSettingsDialog extends ConsumerStatefulWidget {
  const ReminderSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: context.colors.overlay,
      builder: (_) => const ReminderSettingsDialog(),
    );
  }

  @override
  ConsumerState<ReminderSettingsDialog> createState() =>
      _ReminderSettingsDialogState();
}

class _ReminderSettingsDialogState
    extends ConsumerState<ReminderSettingsDialog> {
  Set<ReminderRule>? _rules;
  TimeOfDay? _digestTime;
  bool? _weekendReminders;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = ref.watch(appSettingsProvider).value;

    final rules = _rules ??
        settings?.enabledReminderRules ??
        ReminderRule.values.toSet();
    final digestTime = _digestTime ??
        settings?.dailyDigestTime ??
        AppSettings.defaultDailyDigestTime;
    final weekendReminders =
        _weekendReminders ?? settings?.weekendReminders ?? false;

    return AppDialog(
      title: 'Reminder Settings',
      subtitle: 'Configure automated notifications for planned work',
      icon: Icons.notifications_active_outlined,
      width: DialogWidth.medium,
      onSubmit: () => _save(rules, digestTime, weekendReminders),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _save(rules, digestTime, weekendReminders),
          child: const Text('Save'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Reminder Rules',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          for (final rule in ReminderRule.values) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: rules.contains(rule),
              title: Text(
                rule.label,
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
              ),
              onChanged: (val) {
                final next = Set<ReminderRule>.from(rules);
                if (val == true) {
                  next.add(rule);
                } else {
                  next.remove(rule);
                }
                setState(() => _rules = next);
              },
            ),
          ],
          const SizedBox(height: Spacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Digest Time',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Time for morning and overdue reminders',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time, size: 14),
                label: Text(
                  '${digestTime.hour.toString().padLeft(2, '0')}:${digestTime.minute.toString().padLeft(2, '0')}',
                ),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: digestTime,
                  );
                  if (picked != null) {
                    setState(() => _digestTime = picked);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Weekend Reminders',
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
            ),
            subtitle: Text(
              'Allow notifications on Saturday and Sunday',
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
            value: weekendReminders,
            onChanged: (val) => setState(() => _weekendReminders = val),
          ),
        ],
      ),
    );
  }

  Future<void> _save(
    Set<ReminderRule> rules,
    TimeOfDay digestTime,
    bool weekendReminders,
  ) async {
    final notifier = ref.read(appSettingsProvider.notifier);
    for (final rule in ReminderRule.values) {
      await notifier.setReminderRule(rule, rules.contains(rule));
    }
    await notifier.setDailyDigestTime(digestTime);
    await notifier.setWeekendReminders(weekendReminders);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
