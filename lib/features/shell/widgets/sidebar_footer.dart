import 'package:flutter/material.dart';
import 'package:workpulse/core/constants/app_constants.dart';
import 'package:workpulse/core/keyboard/shortcut_labels.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/segmented_control.dart';
import 'package:workpulse/features/settings/providers/app_settings_provider.dart';

/// Appearance control, idle threshold, shortcut editor and version, pinned to
/// the bottom of the sidebar.
class SidebarFooter extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String hotKeyLabel;
  final VoidCallback? onEditShortcut;
  final bool isCollapsed;

  /// How long without input before the idle prompt appears. Null while
  /// settings are still loading.
  final Duration? idleThreshold;
  final ValueChanged<Duration> onIdleThresholdChanged;

  const SidebarFooter({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.hotKeyLabel,
    required this.onEditShortcut,
    required this.idleThreshold,
    required this.onIdleThresholdChanged,
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
            _IdleThresholdButton(
              value: idleThreshold,
              onChanged: onIdleThresholdChanged,
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
          // The shortcut editor and the idle threshold share a row so adding
          // the second control costs the nav list no vertical space — the
          // sidebar is only 220pt wide and the rail above it has to stay
          // scroll-free at the app's minimum window height.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEditShortcut,
                  icon: const Icon(Icons.keyboard_outlined, size: IconSizes.sm),
                  label: Text(hotKeyLabel, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    minimumSize: const Size(0, ControlSizes.toolbar),
                    textStyle: theme.textTheme.labelMedium,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              _IdleThresholdButton(
                value: idleThreshold,
                onChanged: onIdleThresholdChanged,
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm + 2),
          Text(
            'v${AppConstants.appVersion} • ${ShortcutLabels.platformName}',
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

/// Picks how long the machine must go without input before WorkPulse asks
/// what happened.
///
/// The threshold is required to be configurable
/// (`docs/WORKPULSE_SPEC.md` §31) but was fixed in code with no way to reach
/// it. Rendered as an icon button with a menu rather than a labelled select so
/// it costs the sidebar no height.
class _IdleThresholdButton extends StatelessWidget {
  final Duration? value;
  final ValueChanged<Duration> onChanged;

  const _IdleThresholdButton({required this.value, required this.onChanged});

  static String label(Duration threshold) => '${threshold.inMinutes} min';

  @override
  Widget build(BuildContext context) {
    final current = value;

    return MenuAnchor(
      menuChildren: [
        for (final option in idleThresholdOptions)
          MenuItemButton(
            onPressed: () => onChanged(option),
            leadingIcon: Icon(
              option == current ? Icons.check : Icons.hourglass_empty,
              size: IconSizes.sm,
            ),
            child: Text(label(option)),
          ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: current == null
            ? 'Idle prompt threshold'
            : 'Idle prompt after ${label(current)} without input',
        child: OutlinedButton(
          onPressed: current == null
              ? null
              : () =>
                  controller.isOpen ? controller.close() : controller.open(),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.textSecondary,
            minimumSize: const Size(0, ControlSizes.toolbar),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            textStyle: Theme.of(context).textTheme.labelMedium,
          ),
          child: Text(current == null ? '—' : label(current)),
        ),
      ),
    );
  }
}
