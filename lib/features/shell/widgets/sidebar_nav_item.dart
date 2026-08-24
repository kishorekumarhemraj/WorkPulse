import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/keyboard/shortcut_labels.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/hoverable.dart';
import 'package:workpulse/features/shell/models/shell_nav_tab.dart';

/// A single sidebar destination.
///
/// Carries a live count badge, an active indicator bar, and — when the
/// sidebar is collapsed — a tooltip naming the destination and its shortcut,
/// so the icon rail stays usable.
class SidebarNavItem extends ConsumerStatefulWidget {
  final ShellNavTab tab;
  final bool isSelected;
  final bool isCollapsed;
  final Provider<int?>? countProvider;
  final VoidCallback onTap;

  const SidebarNavItem({
    super.key,
    required this.tab,
    required this.isSelected,
    required this.onTap,
    this.isCollapsed = false,
    this.countProvider,
  });

  @override
  ConsumerState<SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends ConsumerState<SidebarNavItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final isSelected = widget.isSelected;
    final isCollapsed = widget.isCollapsed;
    final countProvider = widget.countProvider;

    final colors = context.colors;
    final theme = Theme.of(context);
    final count = countProvider != null ? ref.watch(countProvider) : null;

    final foreground = isSelected ? colors.accent : colors.textSecondary;

    Widget item = Hoverable(
      cursor: SystemMouseCursors.click,
      builder: (context, isHovered) {
        return AnimatedContainer(
          duration: Motion.duration(context, Motion.fast),
          curve: Motion.curve,
          decoration: BoxDecoration(
            color: isSelected
                ? colors.selected
                : (isHovered ? colors.hover : Colors.transparent),
            borderRadius: Radii.smAll,
            // The rail is the app's primary navigation; without this a
            // keyboard user tabbing into it had no idea where they were.
            border: _isFocused
                ? Border.all(color: colors.focusRing, width: 2)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: Radii.smAll,
              onFocusChange: (hasFocus) {
                if (hasFocus == _isFocused) return;
                setState(() => _isFocused = hasFocus);
              },
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCollapsed ? Spacing.sm : Spacing.md - 2,
                  vertical: Spacing.sm + 1,
                ),
                child: Row(
                  mainAxisAlignment: isCollapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(tab.icon, size: IconSizes.lg, color: foreground),
                    if (!isCollapsed) ...[
                      const SizedBox(width: Spacing.md - 2),
                      Expanded(
                        child: Text(
                          tab.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isSelected ? colors.textPrimary : foreground,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (count != null && count > 0)
                        _CountBadge(count: count, isSelected: isSelected),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    // The collapsed rail has no labels, so the tooltip has to carry both the
    // destination name and its shortcut.
    if (isCollapsed) {
      item = Tooltip(
        message:
            '${tab.label}   ${ShortcutLabels.primary('${tab.shortcutDigit}')}',
        child: item,
      );
    }

    return Semantics(
      selected: isSelected,
      button: true,
      label: tab.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: item,
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final bool isSelected;

  const _CountBadge({required this.count, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xs + 1,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: isSelected ? colors.accentSubtle : colors.card,
        borderRadius: Radii.pillAll,
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: AppTypography.numeric(
          fontSize: 11,
          color: isSelected ? colors.accent : colors.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
