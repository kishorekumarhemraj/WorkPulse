import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workpulse/core/keyboard/menu_keyboard.dart';
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
///
/// Stateful for the sake of one thing: a focus node. The trigger used to be a
/// bare [InkWell], so tabbing onto it moved the keyboard cursor somewhere with
/// nothing at all to show for it — the palette has always had a focusRing
/// token and this control never drew it.
class AppFilterDropdown<T> extends StatefulWidget {
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
  State<AppFilterDropdown<T>> createState() => _AppFilterDropdownState<T>();
}

class _AppFilterDropdownState<T> extends State<AppFilterDropdown<T>> {
  static const double _rowHeight = 32;
  static const double _menuMinWidth = 180;
  static const double _menuMaxWidth = 280;
  static const double _menuMaxHeight = 320;

  final FocusNode _focusNode = FocusNode();
  final MenuKeyboard _menuKeyboard = MenuKeyboard();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _menuKeyboard.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus == _isFocused) return;
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  /// Keys that open a closed dropdown — the same set [AppSelect] accepts, so
  /// the two controls do not disagree about what opens a menu.
  static bool _opensMenu(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    // Guard against a stale selection whose entity has been deleted.
    final selectedOption = widget.value != null
        ? widget.options.where((o) => o.value == widget.value).firstOrNull
        : null;
    final hasValue = selectedOption != null;

    // Row 0 is the "clear the filter" row, so every option sits one later.
    final selectedRow =
        hasValue ? widget.options.indexOf(selectedOption) + 1 : 0;

    _menuKeyboard.setLabels([
      widget.placeholder,
      for (final option in widget.options) option.label,
    ]);

    return MenuAnchor(
      onOpen: () => _menuKeyboard.focusAfterOpen(selectedRow),
      onClose: () {
        if (mounted) _focusNode.requestFocus();
      },
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
          label: widget.placeholder,
          icon: widget.leadingIcon,
          focusNode: _menuKeyboard.nodeAt(0),
          isSelected: !hasValue,
          height: _rowHeight,
          minWidth: _menuMinWidth,
          maxWidth: _menuMaxWidth,
          onSelected: () => widget.onChanged(null),
        ),
        for (final (index, option) in widget.options.indexed)
          _FilterMenuItem(
            label: option.label,
            color: option.color,
            icon: option.icon ?? widget.leadingIcon,
            focusNode: _menuKeyboard.nodeAt(index + 1),
            isSelected: option.value == widget.value,
            height: _rowHeight,
            minWidth: _menuMinWidth,
            maxWidth: _menuMaxWidth,
            onSelected: () => widget.onChanged(option.value),
          ),
      ],
      builder: (context, controller, _) {
        return Hoverable(
          cursor: SystemMouseCursors.click,
          builder: (context, isHovered) {
            // Focus outranks the applied-filter tint: it answers "where am
            // I?", which the user only asks while the answer is not already
            // visible.
            final Color borderColor;
            final double borderWidth;
            if (_isFocused) {
              borderColor = colors.focusRing;
              borderWidth = 1.5;
            } else if (hasValue) {
              borderColor = colors.accent.withValues(alpha: Alphas.strong);
              borderWidth = 1.0;
            } else {
              borderColor = isHovered ? colors.borderStrong : colors.divider;
              borderWidth = 1.0;
            }

            return Material(
              color: Colors.transparent,
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent && _opensMenu(event.logicalKey)) {
                    if (!controller.isOpen) {
                      controller.open();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: InkWell(
                  // The Focus above owns the keyboard cursor; a focusable
                  // InkWell underneath it would be a second, invisible stop.
                  canRequestFocus: false,
                  borderRadius: Radii.mdAll,
                  onTap: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                  child: Container(
                    height: ControlSizes.toolbar,
                    constraints: const BoxConstraints(maxWidth: 220),
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                    decoration: BoxDecoration(
                      color: hasValue ? colors.accentSubtle : colors.field,
                      borderRadius: Radii.mdAll,
                      border: Border.all(
                        color: borderColor,
                        width: borderWidth,
                      ),
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
                            widget.leadingIcon != null) ...[
                          Icon(
                            selectedOption?.icon ?? widget.leadingIcon,
                            size: IconSizes.sm,
                            color:
                                hasValue ? colors.accent : colors.textSecondary,
                          ),
                          const SizedBox(width: Spacing.sm - 2),
                        ],
                        Flexible(
                          child: Text(
                            selectedOption?.label ?? widget.placeholder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: hasValue
                                  ? colors.accent
                                  : colors.textSecondary,
                              fontWeight:
                                  hasValue ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Icon(
                          Icons.expand_more,
                          size: IconSizes.md,
                          color:
                              hasValue ? colors.accent : colors.textSecondary,
                        ),
                      ],
                    ),
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
  final FocusNode focusNode;
  final bool isSelected;
  final double height;
  final double minWidth;
  final double maxWidth;
  final VoidCallback onSelected;

  const _FilterMenuItem({
    required this.label,
    this.color,
    this.icon,
    required this.focusNode,
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
      focusNode: focusNode,
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        minimumSize: WidgetStatePropertyAll(Size(minWidth, height)),
        maximumSize: WidgetStatePropertyAll(Size(maxWidth, height)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Spacing.md),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused) ||
              states.contains(WidgetState.hovered)) {
            return colors.hover;
          }
          return isSelected ? colors.accentSubtle : Colors.transparent;
        }),
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
