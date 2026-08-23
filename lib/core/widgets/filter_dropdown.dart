import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// One entry in an [AppFilterDropdown].
class FilterOption<T> {
  final T value;
  final String label;

  /// A colour dot drawn before the label — project and tag hues.
  final Color? color;

  /// An icon drawn before the label, when the entity has no colour.
  final IconData? icon;

  const FilterOption({
    required this.value,
    required this.label,
    this.color,
    this.icon,
  });
}

/// A toolbar filter dropdown that visibly marks itself when a filter is
/// applied.
///
/// Consolidates the three near-identical hand-built dropdowns in the Work
/// Items toolbar (project / category / tag).
class AppFilterDropdown<T> extends StatelessWidget {
  /// Label shown when nothing is selected, e.g. "All Projects".
  final String placeholder;
  final T? value;
  final List<FilterOption<T>> options;
  final ValueChanged<T?> onChanged;
  final IconData? leadingIcon;

  const AppFilterDropdown({
    super.key,
    required this.placeholder,
    required this.value,
    required this.options,
    required this.onChanged,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    // Guard against a stale selection whose entity has been deleted.
    final hasValue = value != null && options.any((o) => o.value == value);
    final effectiveValue = hasValue ? value : null;

    return Container(
      height: ControlSizes.toolbar,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      decoration: BoxDecoration(
        color: hasValue ? colors.accentSubtle : colors.card,
        borderRadius: Radii.mdAll,
        border: Border.all(
          color:
              hasValue ? colors.accent.withValues(alpha: 0.6) : colors.divider,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: effectiveValue,
          isDense: true,
          borderRadius: Radii.mdAll,
          dropdownColor: colors.surfaceRaised,
          focusColor: Colors.transparent,
          style: theme.textTheme.bodyMedium,
          icon: Icon(
            Icons.expand_more,
            size: IconSizes.md,
            color: hasValue ? colors.accent : colors.textSecondary,
          ),
          hint: _Label(
            text: placeholder,
            icon: leadingIcon,
            color: colors.textSecondary,
          ),
          selectedItemBuilder: (context) => [
            _Label(
              text: placeholder,
              icon: leadingIcon,
              color: colors.textSecondary,
            ),
            ...options.map(
              (o) => _Label(
                text: o.label,
                icon: o.icon ?? leadingIcon,
                dotColor: o.color,
                color: colors.accent,
                bold: true,
              ),
            ),
          ],
          items: [
            DropdownMenuItem<T?>(
              value: null,
              child: _Label(
                text: placeholder,
                icon: leadingIcon,
                color: colors.textSecondary,
              ),
            ),
            ...options.map(
              (o) => DropdownMenuItem<T?>(
                value: o.value,
                child: _Label(
                  text: o.label,
                  icon: o.icon,
                  dotColor: o.color,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? dotColor;
  final Color color;
  final bool bold;

  const _Label({
    required this.text,
    required this.color,
    this.icon,
    this.dotColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dotColor != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: Spacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: IconSizes.sm, color: color),
          const SizedBox(width: Spacing.sm - 2),
        ],
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
        ),
      ],
    );
  }
}
