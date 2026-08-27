import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// One choice in an [AppRadioGroup].
class RadioOption<T> {
  final T value;
  final String label;

  /// A short gloss shown under the label. Optional — a group of one-word
  /// choices reads better without it.
  final String? description;

  final IconData? icon;

  const RadioOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
  });
}

/// A horizontal group of mutually exclusive choices.
///
/// Deliberately not built on Material's [Radio]: that widget's selection API
/// is mid-migration upstream, and this group also has to render as a pair of
/// tappable cards rather than a bare dot beside a label.
///
/// Each option is focusable and activates on Enter or Space, so the group is
/// reachable with Tab like every other control in a WorkPulse form.
class AppRadioGroup<T> extends StatelessWidget {
  final List<RadioOption<T>> options;
  final T? selected;
  final ValueChanged<T> onChanged;

  /// Stretches the options to share the full available width.
  final bool fillWidth;

  const AppRadioGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.fillWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (final option in options)
        Padding(
          padding: const EdgeInsets.only(right: Spacing.sm),
          child: _RadioCard<T>(
            option: option,
            isSelected: option.value == selected,
            onTap: () => onChanged(option.value),
          ),
        ),
    ];

    if (!fillWidth) {
      return Wrap(
        spacing: 0,
        runSpacing: Spacing.sm,
        children: children,
      );
    }

    return Row(
      children: [
        for (final child in children) Expanded(child: child),
      ],
    );
  }
}

class _RadioCard<T> extends StatelessWidget {
  final RadioOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;

  const _RadioCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Semantics(
      label: option.label,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.mdAll,
        child: AnimatedContainer(
          duration: Motion.duration(context, Motion.fast),
          curve: Motion.curve,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.md - 2,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colors.accentSubtle : colors.field,
            borderRadius: Radii.mdAll,
            border: Border.all(
              color: isSelected ? colors.accent : colors.divider,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              _RadioDot(isSelected: isSelected),
              const SizedBox(width: Spacing.sm),
              if (option.icon != null) ...[
                Icon(
                  option.icon,
                  size: IconSizes.md,
                  color: isSelected ? colors.accent : colors.textSecondary,
                ),
                const SizedBox(width: Spacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (option.description != null) ...[
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        option.description!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The selection indicator: a ring that fills when chosen.
///
/// Shape carries the state as well as colour does, so the group still reads
/// correctly to someone who cannot separate the accent from the border.
class _RadioDot extends StatelessWidget {
  final bool isSelected;

  const _RadioDot({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: IconSizes.md,
      height: IconSizes.md,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? colors.accent : colors.borderStrong,
          width: 1.5,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: Spacing.sm,
                height: Spacing.sm,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
