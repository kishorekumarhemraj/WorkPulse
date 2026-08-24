import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// A standard date navigation stepper control with previous, current, and next actions.
class AppDateStepper extends StatelessWidget {
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;
  final double height;

  const AppDateStepper({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
    this.height = ControlSizes.standard,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.mdAll,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: IconSizes.md),
            tooltip: 'Previous day',
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: height,
              maxWidth: height,
              minHeight: height,
              maxHeight: height,
            ),
            onPressed: onPrevious,
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: Radii.smAll,
              onTap: onPickDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: IconSizes.sm,
                      color: colors.accent,
                    ),
                    const SizedBox(width: Spacing.xs + 2),
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: IconSizes.md),
            tooltip: 'Next day',
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: height,
              maxWidth: height,
              minHeight: height,
              maxHeight: height,
            ),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
