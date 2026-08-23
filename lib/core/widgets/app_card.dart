import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/hoverable.dart';

/// The app's standard content surface.
///
/// Every panel, metric tile and list row previously built its own
/// Container + BoxDecoration with slightly different radius and border
/// treatment; this centralises that so surfaces are consistent and hover /
/// selection / emphasis states behave the same everywhere.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Draws the accent border and tint used for the selected row in a list.
  final bool isSelected;

  /// An accent colour for the card's border and glow — used to mark the
  /// work item currently being tracked.
  final Color? emphasisColor;

  /// A vertical colour strip down the leading edge, carrying the project
  /// colour on list rows.
  final Color? leadingStripe;

  final double radius;
  final bool showBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.onTap,
    this.isSelected = false,
    this.emphasisColor,
    this.leadingStripe,
    this.radius = Radii.xl,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(radius);

    return Hoverable(
      cursor:
          onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      builder: (context, isHovered) {
        final Color borderColor;
        if (emphasisColor != null) {
          borderColor = emphasisColor!.withValues(alpha: 0.7);
        } else if (isSelected) {
          borderColor = colors.accent.withValues(alpha: 0.7);
        } else if (isHovered && onTap != null) {
          borderColor = colors.borderStrong;
        } else {
          borderColor = colors.divider;
        }

        return AnimatedContainer(
          duration: Motion.duration(context, Motion.fast),
          curve: Motion.curve,
          decoration: BoxDecoration(
            color: isSelected ? colors.selected : colors.surface,
            borderRadius: borderRadius,
            border: showBorder
                ? Border.all(
                    color: borderColor,
                    width: (emphasisColor != null || isSelected) ? 1.5 : 1,
                  )
                : null,
            boxShadow: emphasisColor != null
                ? [
                    BoxShadow(
                      color: emphasisColor!.withValues(alpha: 0.12),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color:
                isHovered && onTap != null ? colors.hover : Colors.transparent,
            borderRadius: borderRadius,
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              // The card paints its own hover fill above, so suppress the
              // default ink highlight and keep only the ripple.
              hoverColor: Colors.transparent,
              // Without a stripe there is no Row at all: a stretch Row needs a
              // bounded height, which a card laid out inside a scroll view or
              // a shrink-wrapping Wrap does not have.
              child: leadingStripe == null
                  ? Padding(padding: padding, child: child)
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: leadingStripe,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(radius),
                                bottomLeft: Radius.circular(radius),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(padding: padding, child: child),
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

/// A card with a title row, used for dashboard panels.
class AppSectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(Spacing.lg + 2),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: IconSizes.md, color: colors.accent),
                const SizedBox(width: Spacing.sm),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Spacing.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: Spacing.lg),
          child,
        ],
      ),
    );
  }
}
