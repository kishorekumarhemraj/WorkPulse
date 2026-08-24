import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/hoverable.dart';

/// One choice in an [AppSelect].
class SelectOption<T> {
  final T value;
  final String label;

  /// A colour dot drawn before the label — project, tag and option hues.
  final Color? color;

  /// An icon drawn before the label, for entities carrying one instead of a
  /// colour.
  final IconData? icon;

  const SelectOption({
    required this.value,
    required this.label,
    this.color,
    this.icon,
  });
}

/// A compact single-choice select for forms.
///
/// `DropdownButtonFormField` stretches to its container and opens a menu of
/// 48pt rows the same width, which reads as a heavy slab in a dialog where
/// the choice itself is two words long. This sizes the trigger to its content
/// instead — a bordered pill with dot/icon, label and chevron — and anchors a
/// tight menu of [_rowHeight] rows beneath it.
///
/// Built on [FormField] so `validator` still participates in the enclosing
/// [Form], and on [MenuAnchor] so arrow-key traversal, Enter to choose and
/// Escape to dismiss come for free.
class AppSelect<T> extends StatefulWidget {
  /// The current selection. The caller owns this value; [AppSelect] never
  /// holds its own copy for display.
  final T? value;
  final List<SelectOption<T>> options;
  final ValueChanged<T?> onChanged;

  /// Shown in the trigger when nothing is selected.
  final String placeholder;

  /// Optional caption rendered above the trigger.
  final String? label;

  /// Marks [label] with an asterisk.
  final bool isRequired;

  final FormFieldValidator<T>? validator;

  /// A disabled select still shows its value but cannot be opened — used for
  /// fields that are immutable after creation.
  final bool enabled;

  /// Caps how wide the trigger may grow, so one long project name cannot
  /// stretch the row it sits in.
  final double maxTriggerWidth;

  const AppSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.placeholder,
    this.label,
    this.isRequired = false,
    this.validator,
    this.enabled = true,
    this.maxTriggerWidth = 260,
  });

  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>> {
  /// Deliberately shorter than Material's 48pt default: these menus list
  /// short entity names, and the density is the whole point of the control.
  static const double _rowHeight = 32;
  static const double _menuMinWidth = 200;
  static const double _menuMaxWidth = 320;
  static const double _menuMaxHeight = 320;

  final FocusNode _focusNode = FocusNode();
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
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus == _isFocused) return;
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  SelectOption<T>? get _selected {
    for (final option in widget.options) {
      if (option.value == widget.value) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: widget.value,
      validator: widget.validator,
      enabled: widget.enabled,
      builder: (field) {
        // The caller owns the value; keep the FormField's copy — which is what
        // the validator reads — in step when it changes from outside.
        if (field.value != widget.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (field.mounted) field.didChange(widget.value);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.label != null) ...[
              _Caption(text: widget.label!, isRequired: widget.isRequired),
              const SizedBox(height: Spacing.xs + 2),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: _buildAnchor(context, field),
            ),
            if (field.errorText != null) ...[
              const SizedBox(height: Spacing.xs + 2),
              Text(
                field.errorText!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.colors.danger),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAnchor(BuildContext context, FormFieldState<T> field) {
    return MenuAnchor(
      // Clears the trigger's border rather than overlapping it.
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
        for (final option in widget.options)
          _SelectMenuItem<T>(
            option: option,
            isSelected: option.value == widget.value,
            height: _rowHeight,
            minWidth: _menuMinWidth,
            maxWidth: _menuMaxWidth,
            onSelected: () {
              field.didChange(option.value);
              widget.onChanged(option.value);
            },
          ),
      ],
      builder: (context, controller, _) => _buildTrigger(
        context,
        controller,
        hasError: field.errorText != null,
      ),
    );
  }

  Widget _buildTrigger(
    BuildContext context,
    MenuController controller, {
    required bool hasError,
  }) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final selected = _selected;
    final isEmpty = selected == null;

    return Hoverable(
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      builder: (context, isHovered) {
        final Color borderColor;
        final double borderWidth;
        if (hasError) {
          borderColor = colors.danger;
          borderWidth = _isFocused ? 1.5 : 1.0;
        } else if (_isFocused) {
          borderColor = colors.focusRing;
          borderWidth = 1.5;
        } else if (isHovered && widget.enabled) {
          borderColor = colors.borderStrong;
          borderWidth = 1.0;
        } else {
          borderColor = widget.enabled
              ? colors.divider
              : colors.divider.withValues(alpha: 0.5);
          borderWidth = 1.0;
        }

        final foreground = !widget.enabled
            ? colors.textTertiary
            : (isEmpty ? colors.textTertiary : colors.textPrimary);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            focusNode: _focusNode,
            canRequestFocus: widget.enabled,
            borderRadius: Radii.mdAll,
            onTap: widget.enabled
                ? () => controller.isOpen ? controller.close() : controller.open()
                : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxTriggerWidth),
              child: Container(
                height: ControlSizes.standard,
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                decoration: BoxDecoration(
                  color: widget.enabled
                      ? colors.card
                      : colors.card.withValues(alpha: 0.5),
                  borderRadius: Radii.mdAll,
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected != null)
                      _OptionGlyph(option: selected, color: colors.accent),
                    Flexible(
                      child: Text(
                        selected?.label ?? widget.placeholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontWeight:
                              isEmpty ? FontWeight.w400 : FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Icon(
                      Icons.expand_more,
                      size: IconSizes.md,
                      color: widget.enabled
                          ? colors.textSecondary
                          : colors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The colour dot or icon that precedes an option's label.
class _OptionGlyph extends StatelessWidget {
  final SelectOption<Object?> option;
  final Color color;

  const _OptionGlyph({required this.option, required this.color});

  @override
  Widget build(BuildContext context) {
    if (option.color != null) {
      return Padding(
        padding: const EdgeInsets.only(right: Spacing.sm),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: option.color,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    if (option.icon != null) {
      return Padding(
        padding: const EdgeInsets.only(right: Spacing.sm - 2),
        child: Icon(option.icon, size: IconSizes.sm, color: color),
      );
    }
    return const SizedBox.shrink();
  }
}

class _SelectMenuItem<T> extends StatelessWidget {
  final SelectOption<T> option;
  final bool isSelected;
  final double height;
  final double minWidth;
  final double maxWidth;
  final VoidCallback onSelected;

  const _SelectMenuItem({
    required this.option,
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
        // Without shrinkWrap the button pads itself out to Material's 48pt
        // minimum tap target, which is the bulk being removed here.
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // Density is already expressed by [minimumSize]; leaving it compact
        // would subtract a further 8px and squeeze the label.
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
          _OptionGlyph(option: option, color: colors.accent),
          Expanded(
            child: Text(
              option.label,
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

/// The small field caption above a select.
class _Caption extends StatelessWidget {
  final String text;
  final bool isRequired;

  const _Caption({required this.text, required this.isRequired});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      isRequired ? '$text *' : text,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: colors.textSecondary),
    );
  }
}

/// A quiet stand-in that holds an [AppSelect]'s footprint while its options
/// load, so the form does not jump once they arrive.
class AppSelectPlaceholder extends StatelessWidget {
  final String label;

  const AppSelectPlaceholder({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: ControlSizes.standard,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.5),
          borderRadius: Radii.mdAll,
          border: Border.all(color: colors.divider.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colors.textTertiary),
        ),
      ),
    );
  }
}
