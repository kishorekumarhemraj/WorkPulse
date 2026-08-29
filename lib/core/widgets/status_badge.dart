import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// The semantic meaning a [StatusBadge] carries.
enum BadgeTone { neutral, accent, success, warning, danger, info }

/// A compact status pill — `TRACKING`, `ARCHIVED`, `ACTIVE`, and so on.
///
/// Replaces roughly twenty-five hand-rolled Container+BoxDecoration badges
/// that had drifted apart on padding, radius and text size.
///
/// A badge always pairs its colour with a label, and usually an icon, so
/// status is never communicated by colour alone.
class StatusBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final BadgeTone tone;

  /// Overrides the tone colour — used for project and tag hues, which come
  /// from user data rather than the semantic palette.
  final Color? color;

  /// Renders uppercase with wide tracking, for hard status states.
  final bool emphasis;

  /// Draws a border in addition to the tinted fill.
  final bool outlined;

  const StatusBadge({
    super.key,
    required this.label,
    this.icon,
    this.tone = BadgeTone.neutral,
    this.color,
    this.emphasis = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final (Color foreground, Color fill) = switch (tone) {
      BadgeTone.neutral => (colors.textSecondary, colors.card),
      BadgeTone.accent => (colors.accent, colors.accentSubtle),
      BadgeTone.success => (colors.success, colors.successSubtle),
      BadgeTone.warning => (colors.warning, colors.warningSubtle),
      BadgeTone.danger => (colors.danger, colors.dangerSubtle),
      BadgeTone.info => (colors.info, colors.infoSubtle),
    };

    final fg = color ?? foreground;
    final bg = color?.withValues(alpha: Alphas.subtle) ?? fill;

    final textStyle = emphasis
        ? theme.textTheme.labelSmall?.copyWith(color: fg)
        : theme.textTheme.labelMedium
            ?.copyWith(color: fg, fontWeight: FontWeight.w500);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.smAll,
        border: outlined ? Border.all(color: fg.withValues(alpha: Alphas.muted)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: IconSizes.xs, color: fg),
            const SizedBox(width: Spacing.xs),
          ],
          Text(
            emphasis ? label.toUpperCase() : label,
            style: textStyle,
          ),
        ],
      ),
    );
  }
}
