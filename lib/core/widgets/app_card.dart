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
///
/// A tappable card is also a *focusable* card: it draws the palette's
/// [WorkPulseColors.focusRing] when keyboard focus lands on it. Without that,
/// tabbing through Work Items, the library grids or the dashboard tiles moved
/// an invisible cursor — the design system defined a focus ring token that
/// only text inputs ever used.
class AppCard extends StatefulWidget {
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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(widget.radius);
    final isTappable = widget.onTap != null;

    return Hoverable(
      cursor: isTappable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      builder: (context, isHovered) {
        final Color borderColor;
        final double borderWidth;
        // Focus outranks the other states: it answers "where am I?", which the
        // user only asks while the answer is not otherwise visible.
        if (_isFocused) {
          borderColor = colors.focusRing;
          borderWidth = 2;
        } else if (widget.emphasisColor != null) {
          borderColor = widget.emphasisColor!.withValues(alpha: 0.7);
          borderWidth = 1.5;
        } else if (widget.isSelected) {
          borderColor = colors.accent.withValues(alpha: 0.7);
          borderWidth = 1.5;
        } else if (isHovered && isTappable) {
          borderColor = colors.borderStrong;
          borderWidth = 1;
        } else {
          borderColor = colors.divider;
          borderWidth = 1;
        }

        return AnimatedContainer(
          duration: Motion.duration(context, Motion.fast),
          curve: Motion.curve,
          decoration: BoxDecoration(
            color: widget.isSelected ? colors.selected : colors.surface,
            borderRadius: borderRadius,
            border: widget.showBorder || _isFocused
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
            boxShadow: widget.emphasisColor != null
                ? [
                    BoxShadow(
                      color: widget.emphasisColor!.withValues(alpha: 0.12),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : Elevation.low(colors.shadow),
          ),
          child: Material(
            color: isHovered && isTappable ? colors.hover : Colors.transparent,
            borderRadius: borderRadius,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: borderRadius,
              onFocusChange: (hasFocus) {
                if (hasFocus == _isFocused) return;
                setState(() => _isFocused = hasFocus);
              },
              // The card paints its own hover fill above, so suppress the
              // default ink highlight and keep only the ripple. The focus ring
              // is drawn on the border instead of as an overlay so it reads
              // the same on selected, emphasised and plain cards.
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              // Without a stripe there is no Row at all: a stretch Row needs a
              // bounded height, which a card laid out inside a scroll view or
              // a shrink-wrapping Wrap does not have.
              child: widget.leadingStripe == null
                  ? Padding(padding: widget.padding, child: widget.child)
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: widget.leadingStripe,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(widget.radius),
                                bottomLeft: Radius.circular(widget.radius),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: widget.padding,
                              child: widget.child,
                            ),
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
