import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// A themed region, named by the role it plays rather than the colour it is.
///
/// 135 hand-built BoxDecorations against 15 AppCards is why the same note
/// callout was `card` on one screen and `surfaceSunken` on the next. Picking
/// a role is reviewable; picking a hex is not.
enum SurfaceRole {
  /// The Scaffold background of every view, and the window backdrop.
  page,

  /// Cards, list containers, the sidebar, table bodies, day-group containers.
  panel,

  /// Menus, dialogs, popovers, tooltips, snackbars, the command palette.
  raised,

  /// Recessed regions inside a panel: note callouts, code blocks, nested lists.
  well,

  /// Small inset fills on a panel: chip/badge backgrounds, table header rows.
  tint,

  /// Text inputs and editable controls only.
  field,
}

/// A standard surface container styled by [SurfaceRole].
class AppSurface extends StatelessWidget {
  final SurfaceRole role;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? radius;
  final bool? border;
  final Color? borderColor;
  final double? borderWidth;
  final List<BoxShadow>? shadow;
  final Clip clipBehavior;

  const AppSurface({
    super.key,
    required this.role,
    required this.child,
    this.padding,
    this.radius,
    this.border,
    this.borderColor,
    this.borderWidth,
    this.shadow,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final Color backgroundColor;
    final BorderRadius effectiveRadius;
    final bool defaultBorder;
    final List<BoxShadow>? defaultShadow;

    switch (role) {
      case SurfaceRole.page:
        backgroundColor = colors.background;
        effectiveRadius = radius ?? BorderRadius.zero;
        defaultBorder = false;
        defaultShadow = null;
        break;
      case SurfaceRole.panel:
        backgroundColor = colors.surface;
        effectiveRadius = radius ?? Radii.xlAll;
        defaultBorder = true;
        defaultShadow = null;
        break;
      case SurfaceRole.raised:
        backgroundColor = colors.surfaceRaised;
        effectiveRadius = radius ?? Radii.mdAll;
        defaultBorder = true;
        defaultShadow = Elevation.medium(colors.shadow);
        break;
      case SurfaceRole.well:
        backgroundColor = colors.surfaceSunken;
        effectiveRadius = radius ?? Radii.mdAll;
        defaultBorder = true;
        defaultShadow = null;
        break;
      case SurfaceRole.tint:
        backgroundColor = colors.card;
        effectiveRadius = radius ?? Radii.smAll;
        defaultBorder = false;
        defaultShadow = null;
        break;
      case SurfaceRole.field:
        backgroundColor = colors.field;
        effectiveRadius = radius ?? Radii.mdAll;
        defaultBorder = true;
        defaultShadow = null;
        break;
    }

    final hasBorder = border ?? defaultBorder;
    final effectiveShadow = shadow ?? defaultShadow;

    return Container(
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: effectiveRadius,
        border: hasBorder
            ? Border.all(
                color: borderColor ?? colors.divider,
                width: borderWidth ?? 1.0,
              )
            : null,
        boxShadow: effectiveShadow,
      ),
      child: child,
    );
  }
}
