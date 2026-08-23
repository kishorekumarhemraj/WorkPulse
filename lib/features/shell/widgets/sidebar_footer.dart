import 'package:flutter/material.dart';
import 'package:workpulse/core/constants/app_constants.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/segmented_control.dart';

/// Appearance control, shortcut editor and version, pinned to the bottom of
/// the sidebar.
class SidebarFooter extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String hotKeyLabel;
  final VoidCallback? onEditShortcut;
  final bool isCollapsed;

  const SidebarFooter({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.hotKeyLabel,
    required this.onEditShortcut,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.md,
        ),
        child: Column(
          children: [
            Tooltip(
              message: 'Appearance: ${_themeLabel(themeMode)}',
              child: IconButton(
                icon: Icon(_themeIcon(themeMode), size: IconSizes.md),
                onPressed: () => onThemeModeChanged(_nextMode(themeMode)),
              ),
            ),
            Tooltip(
              message: 'Quick Capture shortcut: $hotKeyLabel',
              child: IconButton(
                icon: const Icon(Icons.keyboard_outlined, size: IconSizes.md),
                onPressed: onEditShortcut,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'APPEARANCE',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: Spacing.sm),
          // A three-way control: the previous switch could only reach light
          // and dark, leaving ThemeMode.system unreachable from the UI even
          // though it was already persisted and honoured.
          AppSegmentedControl<ThemeMode>(
            selected: themeMode,
            onChanged: onThemeModeChanged,
            iconOnly: true,
            options: const [
              SegmentOption(
                value: ThemeMode.light,
                label: 'Light',
                icon: Icons.light_mode_outlined,
              ),
              SegmentOption(
                value: ThemeMode.dark,
                label: 'Dark',
                icon: Icons.dark_mode_outlined,
              ),
              SegmentOption(
                value: ThemeMode.system,
                label: 'System',
                icon: Icons.contrast,
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          OutlinedButton.icon(
            onPressed: onEditShortcut,
            icon: const Icon(Icons.keyboard_outlined, size: IconSizes.sm),
            label: Text(hotKeyLabel, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.textSecondary,
              minimumSize: const Size(0, ControlSizes.toolbar),
              textStyle: theme.textTheme.labelMedium,
            ),
          ),
          const SizedBox(height: Spacing.sm + 2),
          Text(
            'v${AppConstants.appVersion} • macOS',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  static ThemeMode _nextMode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
        ThemeMode.system => ThemeMode.light,
      };

  static IconData _themeIcon(ThemeMode mode) => switch (mode) {
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
        ThemeMode.system => Icons.contrast,
      };

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      };
}
