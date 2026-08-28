import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/widgets/app_select.dart';
import 'package:workpulse/features/settings/providers/app_settings_provider.dart';

/// Configures week start day and rounding increment for the Time Sheet grid.
///
/// These settings ensure WorkPulse's entry grid aligns with external
/// timesheet portals (such as IQVIA PeopleSoft) so the weekly cycles and
/// cell decimal values can be transcribed directly.
class TimesheetSettingsDialog extends ConsumerStatefulWidget {
  const TimesheetSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => const TimesheetSettingsDialog(),
    );
  }

  @override
  ConsumerState<TimesheetSettingsDialog> createState() =>
      _TimesheetSettingsDialogState();
}

class _TimesheetSettingsDialogState
    extends ConsumerState<TimesheetSettingsDialog> {
  int? _selectedWeekStartDay;
  double? _selectedRoundingIncrement;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = ref.watch(appSettingsProvider).value;

    final weekStartDay = _selectedWeekStartDay ??
        settings?.timesheetWeekStartDay ??
        AppSettings.defaultTimesheetWeekStartDay;
    final roundingIncrement = _selectedRoundingIncrement ??
        settings?.timesheetRoundingIncrement ??
        AppSettings.defaultTimesheetRoundingIncrement;

    return AppDialog(
      title: 'Time Sheet Settings',
      subtitle: 'Match the entry grid to your organisation\'s timesheet form',
      icon: Icons.tune,
      width: DialogWidth.medium,
      onSubmit: () => _save(weekStartDay, roundingIncrement),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _save(weekStartDay, roundingIncrement),
          child: const Text('Save'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DialogField(
            label: 'Week start day',
            helperText:
                'The day each weekly timesheet grid begins. Defaults to Sunday.',
            child: AppSelect<int>(
              value: weekStartDay,
              placeholder: 'Select start day',
              maxTriggerWidth: double.infinity,
              options: [
                for (final day in timesheetWeekStartDayOptions)
                  SelectOption(
                    value: day,
                    label: weekdayName(day),
                  ),
              ],
              onChanged: (day) {
                if (day != null) {
                  setState(() => _selectedWeekStartDay = day);
                }
              },
            ),
          ),
          const SizedBox(height: Spacing.xl),
          DialogField(
            label: 'Rounding increment',
            helperText:
                'Granularity for each day cell. Row and week totals are the '
                'sum of these rounded cells.',
            child: AppSelect<double>(
              value: roundingIncrement,
              placeholder: 'Select increment',
              maxTriggerWidth: double.infinity,
              options: [
                for (final inc in timesheetRoundingIncrementOptions)
                  SelectOption(
                    value: inc,
                    label: roundingIncrementLabel(inc),
                  ),
              ],
              onChanged: (inc) {
                if (inc != null) {
                  setState(() => _selectedRoundingIncrement = inc);
                }
              },
            ),
          ),
          const SizedBox(height: Spacing.xl),
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: Radii.mdAll,
              border: Border.all(color: colors.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: IconSizes.sm,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'WorkPulse sums already-rounded cells so your week '
                    'totals match what external timesheet forms calculate.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(int weekStartDay, double roundingIncrement) async {
    final notifier = ref.read(appSettingsProvider.notifier);
    await notifier.setTimesheetWeekStartDay(weekStartDay);
    await notifier.setTimesheetRoundingIncrement(roundingIncrement);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
