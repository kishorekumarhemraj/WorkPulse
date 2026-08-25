import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// A chip identifying a domain entity — a project, category, tag or person.
///
/// The leading marker is either a coloured dot (projects, tags, whose colour
/// is user-chosen data) or an icon (categories, people). This is the one
/// place in the app where user colour is rendered, so it stays consistent
/// everywhere an entity is referenced.
class EntityChip extends StatelessWidget {
  final String label;

  /// The entity's own colour. When set, a dot is drawn and the label is
  /// tinted to match.
  final Color? color;

  /// Shown instead of the dot when the entity has no colour of its own.
  final IconData? icon;

  final VoidCallback? onTap;

  /// Removes the fill, leaving just marker + label. Used in dense rows.
  final bool plain;

  const EntityChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.onTap,
    this.plain = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final tint = color ?? colors.textSecondary;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (color != null)
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          )
        else if (icon != null)
          Icon(icon, size: IconSizes.xs, color: colors.textSecondary),
        const SizedBox(width: Spacing.xs + 1),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color != null ? tint : colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );

    if (plain) return content;

    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.13) ?? colors.card,
        borderRadius: Radii.smAll,
        // The neutral fill sits close to the page behind it, so the border is
        // what gives an uncoloured chip an edge rather than pure decoration.
        border: Border.all(
          color: color?.withValues(alpha: 0.28) ?? colors.divider,
        ),
      ),
      child: content,
    );

    if (onTap == null) return chip;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.smAll,
        child: chip,
      ),
    );
  }
}

/// A chip showing a duration or other numeric value in the tabular
/// monospace face, so values line up when stacked in a list.
class MetricChip extends StatelessWidget {
  final String value;
  final IconData? icon;
  final Color? color;
  final bool emphasis;
  final VoidCallback? onTap;

  const MetricChip({
    super.key,
    required this.value,
    this.icon,
    this.color,
    this.emphasis = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = color ?? colors.textSecondary;

    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.13) ?? colors.card,
        borderRadius: Radii.smAll,
        border: Border.all(
          color: color?.withValues(alpha: 0.3) ?? colors.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: IconSizes.xs, color: fg),
            const SizedBox(width: Spacing.xs),
          ],
          Text(
            value,
            style: AppTypography.numeric(
              fontSize: 12,
              color: fg,
              fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: Radii.smAll, child: chip),
    );
  }
}
