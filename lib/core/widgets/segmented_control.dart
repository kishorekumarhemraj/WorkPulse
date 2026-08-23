import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// One option in an [AppSegmentedControl].
class SegmentOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final String? tooltip;

  const SegmentOption({
    required this.value,
    required this.label,
    this.icon,
    this.tooltip,
  });
}

/// A macOS-style segmented picker.
///
/// Replaces the date-range pill group that was duplicated verbatim between
/// the Dashboard and the Time Log, and is reused for scope filters, density
/// toggles and the theme picker.
class AppSegmentedControl<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Renders icons only, with the label moved into the tooltip.
  final bool iconOnly;

  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: Radii.mdAll,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final isSelected = option.value == selected;
          final foreground =
              isSelected ? colors.textPrimary : colors.textSecondary;

          Widget segment = AnimatedContainer(
            duration: Motion.duration(context, Motion.fast),
            curve: Motion.curve,
            padding: EdgeInsets.symmetric(
              horizontal: iconOnly ? Spacing.sm : Spacing.md,
              vertical: Spacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: isSelected ? colors.surface : Colors.transparent,
              borderRadius: Radii.smAll,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null)
                  Icon(option.icon, size: IconSizes.sm, color: foreground),
                if (option.icon != null && !iconOnly)
                  const SizedBox(width: Spacing.xs + 2),
                if (!iconOnly)
                  Text(
                    option.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
              ],
            ),
          );

          segment = Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onChanged(option.value),
              borderRadius: Radii.smAll,
              child: segment,
            ),
          );

          final tooltip = option.tooltip ?? (iconOnly ? option.label : null);
          if (tooltip != null) {
            segment = Tooltip(message: tooltip, child: segment);
          }

          // Announce this as a radio-style selection to assistive tech.
          return Semantics(
            selected: isSelected,
            inMutuallyExclusiveGroup: true,
            button: true,
            label: option.label,
            child: segment,
          );
        }).toList(),
      ),
    );
  }
}
