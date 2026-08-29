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

  /// Stretches the segments to share the full available width.
  ///
  /// The default sizes to content, which is right in a toolbar. Inside a
  /// fixed-width container — a dialog, say — content sizing can exceed the
  /// space available, so those callers pass true.
  final bool fillWidth;

  /// The total height of the segmented control. Defaults to [ControlSizes.standard].
  final double height;

  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.iconOnly = false,
    this.fillWidth = false,
    this.height = ControlSizes.standard,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: Radii.mdAll,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: options.map((option) {
          final isSelected = option.value == selected;
          final foreground =
              isSelected ? colors.textPrimary : colors.textSecondary;

          Widget segment = AnimatedContainer(
            duration: Motion.duration(context, Motion.fast),
            curve: Motion.curve,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              // Stretched segments share a fixed width, so they take less
              // padding to leave room for the label itself.
              horizontal:
                  iconOnly ? Spacing.sm : (fillWidth ? Spacing.sm : Spacing.md),
            ),
            decoration: BoxDecoration(
              color: isSelected ? colors.surface : Colors.transparent,
              borderRadius: Radii.smAll,
              boxShadow: isSelected ? Elevation.low(colors.shadow) : null,
            ),
            child: Row(
              mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (option.icon != null)
                  Icon(option.icon, size: IconSizes.sm, color: foreground),
                if (option.icon != null && !iconOnly)
                  const SizedBox(width: Spacing.xs + 2),
                if (!iconOnly)
                  Flexible(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
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
          final result = Semantics(
            selected: isSelected,
            inMutuallyExclusiveGroup: true,
            button: true,
            label: option.label,
            child: segment,
          );

          return fillWidth ? Expanded(child: result) : result;
        }).toList(),
      ),
    );
  }
}
