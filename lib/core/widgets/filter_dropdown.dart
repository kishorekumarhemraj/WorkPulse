import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/hoverable.dart';

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
/// Follows the same [AppSelect] strategy: compact trigger, [MenuAnchor] popup,
/// dense 32pt menu rows, checkmark on selected, and keyboard navigation.
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

  static const double _rowHeight = 32;
  static const double _menuMinWidth = 180;
  static const double _menuMaxWidth = 280;
  static const double _menuMaxHeight = 320;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    // Guard against a stale selection whose entity has been deleted.
    final selectedOption = value != null
        ? options.where((o) => o.value == value).firstOrNull
        : null;
    final hasValue = selectedOption != null;

    return MenuAnchor(
      alignmentOffset: const Offset(0, Spacing.xs),
      style: const MenuStyle(
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: Spacing.xs),
        ),
        maximumSize: WidgetStatePropertyAll(
          Size(_menuMaxWidth, _menuMaxHeight),
        ),
      ),
      menuChildren: [
        _FilterMenuItem(
          label: placeholder,
          icon: leadingIcon,
          isSelected: !hasValue,
          height: _rowHeight,
          minWidth: _menuMinWidth,
          maxWidth: _menuMaxWidth,
          onSelected: () => onChanged(null),
        ),
        for (final option in options)
          _FilterMenuItem(
            label: option.label,
            color: option.color,
            icon: option.icon ?? leadingIcon,
            isSelected: option.value == value,
            height: _rowHeight,
            minWidth: _menuMinWidth,
            maxWidth: _menuMaxWidth,
            onSelected: () => onChanged(option.value),
          ),
      ],
      builder: (context, controller, _) {
        return Hoverable(
          cursor: SystemMouseCursors.click,
          builder: (context, isHovered) {
            final borderColor = hasValue
                ? colors.accent.withValues(alpha: 0.6)
                : (isHovered ? colors.borderStrong : colors.divider);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: Radii.mdAll,
                onTap: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                child: Container(
                  height: ControlSizes.toolbar,
                  constraints: const BoxConstraints(maxWidth: 220),
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  decoration: BoxDecoration(
                    color: hasValue ? colors.accentSubtle : colors.field,
                    borderRadius: Radii.mdAll,
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedOption?.color != null) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: selectedOption!.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                      ] else if (selectedOption?.icon != null ||
                          leadingIcon != null) ...[
                        Icon(
                          selectedOption?.icon ?? leadingIcon,
                          size: IconSizes.sm,
                          color:
                              hasValue ? colors.accent : colors.textSecondary,
                        ),
                        const SizedBox(width: Spacing.sm - 2),
                      ],
                      Flexible(
                        child: Text(
                          selectedOption?.label ?? placeholder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                hasValue ? colors.accent : colors.textSecondary,
                            fontWeight:
                                hasValue ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Icon(
                        Icons.expand_more,
                        size: IconSizes.md,
                        color: hasValue ? colors.accent : colors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FilterMenuItem extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final bool isSelected;
  final double height;
  final double minWidth;
  final double maxWidth;
  final VoidCallback onSelected;

  const _FilterMenuItem({
    required this.label,
    this.color,
    this.icon,
    required this.isSelected,
    required this.height,
    required this.minWidth,
    required this.maxWidth,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return MenuItemButton(
      onPressed: onSelected,
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        minimumSize: WidgetStatePropertyAll(Size(minWidth, height)),
        maximumSize: WidgetStatePropertyAll(Size(maxWidth, height)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Spacing.md),
        ),
        backgroundColor: WidgetStatePropertyAll(
          isSelected ? colors.accentSubtle : Colors.transparent,
        ),
        overlayColor: WidgetStatePropertyAll(colors.hover),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: Radii.smAll),
        ),
      ),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: Spacing.sm),
          ] else if (icon != null) ...[
            Icon(icon, size: IconSizes.sm, color: colors.accent),
            const SizedBox(width: Spacing.sm - 2),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: Spacing.sm),
            Icon(Icons.check, size: IconSizes.sm, color: colors.accent),
          ],
        ],
      ),
    );
  }
}
