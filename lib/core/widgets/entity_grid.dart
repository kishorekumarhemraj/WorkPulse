import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/core/widgets/hoverable.dart';

/// A menu entry on an [EntityCard].
class EntityAction {
  final String label;
  final IconData icon;
  final bool isDestructive;
  final VoidCallback onSelected;

  const EntityAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.isDestructive = false,
  });
}

/// A card for a project, category, tag or person.
///
/// The four library screens were about 85% identical, each with its own
/// hand-built card, delete confirmation and menu. They now share this, which
/// keeps their behaviour consistent while each screen still supplies its own
/// fields and actions.
class EntityCard extends StatelessWidget {
  final String name;
  final String? description;

  /// The entity's own colour, shown as a swatch. Projects and tags have one.
  final Color? color;

  /// Shown when there is no colour — categories and people.
  final IconData? icon;

  /// e.g. how many work items reference this entity.
  final int? count;
  final String countLabel;

  /// Extra key/value details, e.g. a person's email.
  final List<EntityDetail> details;

  final List<EntityAction> actions;
  final VoidCallback? onTap;

  const EntityCard({
    super.key,
    required this.name,
    this.description,
    this.color,
    this.icon,
    this.count,
    this.countLabel = 'items',
    this.details = const [],
    this.actions = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final accent = color ?? colors.accent;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Spacing.lg),
      // The card fills its grid tile and lets the description absorb the
      // slack, so content can never overflow the tile no matter how long a
      // name or description is — it truncates instead.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: Radii.smAll,
                ),
                child: icon != null
                    ? Icon(icon, size: IconSizes.md, color: accent)
                    : Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: Spacing.md - 2),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actions.isNotEmpty) _ActionMenu(actions: actions),
            ],
          ),
          if (description != null && description!.trim().isNotEmpty) ...[
            const SizedBox(height: Spacing.sm + 2),
            Flexible(
              child: Text(
                description!,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          for (final detail in details) ...[
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                Icon(
                  detail.icon,
                  size: IconSizes.xs,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: Spacing.sm - 2),
                Expanded(
                  child: Text(
                    detail.value,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          if (count != null)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: Radii.pillAll,
                  ),
                  child: Text(
                    '$count',
                    style: AppTypography.numeric(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm - 2),
                Text(
                  count == 1 && countLabel.endsWith('s')
                      ? countLabel.substring(0, countLabel.length - 1)
                      : countLabel,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A labelled detail line on an [EntityCard].
class EntityDetail {
  final IconData icon;
  final String value;

  const EntityDetail({required this.icon, required this.value});
}

class _ActionMenu extends StatelessWidget {
  final List<EntityAction> actions;

  const _ActionMenu({required this.actions});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Hoverable(
      builder: (context, isHovered) => PopupMenuButton<int>(
        icon: Icon(
          Icons.more_vert,
          size: IconSizes.lg,
          color: isHovered ? colors.textPrimary : colors.textSecondary,
        ),
        tooltip: 'More actions',
        onSelected: (index) => actions[index].onSelected(),
        itemBuilder: (context) => [
          for (var i = 0; i < actions.length; i++)
            PopupMenuItem(
              value: i,
              child: Row(
                children: [
                  Icon(
                    actions[i].icon,
                    size: IconSizes.md,
                    color: actions[i].isDestructive
                        ? colors.danger
                        : colors.textPrimary,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    actions[i].label,
                    style: TextStyle(
                      color: actions[i].isDestructive
                          ? colors.danger
                          : colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A responsive grid of [EntityCard]s.
class EntityGrid extends StatelessWidget {
  final List<Widget> children;
  final double maxCardWidth;
  final double cardHeight;

  const EntityGrid({
    super.key,
    required this.children,
    this.maxCardWidth = 340,
    this.cardHeight = 158,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: Spacing.xxl),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCardWidth,
        mainAxisExtent: cardHeight,
        crossAxisSpacing: Spacing.lg,
        mainAxisSpacing: Spacing.lg,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}
