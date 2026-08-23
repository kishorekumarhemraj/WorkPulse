import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/keycap.dart';

/// Standard dialog widths, so dialogs of a kind are always the same size.
abstract class DialogWidth {
  /// 380 — confirmations.
  static const double small = 380;

  /// 520 — single-purpose forms (project, category, tag, person).
  static const double medium = 520;

  /// 680 — multi-section forms (task, session, export).
  static const double large = 680;
}

/// The app's dialog shell: a titled header, a scrolling body, and a footer
/// pinned to the bottom.
///
/// The dialogs previously mixed `AlertDialog` and bare `Dialog` with
/// per-dialog padding and title styling, and several put Save below a long
/// scrolling form where it could be scrolled out of reach. Here the footer is
/// always visible, and `⌘↩` submits from anywhere in the form — which
/// matters most in the task form, the longest one in the app.
class AppDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Tints the header icon — e.g. danger for a delete confirmation.
  final Color? iconColor;

  final Widget child;

  /// Footer buttons, laid out right-aligned. Destructive actions belong on
  /// the left via [leadingFooter].
  final List<Widget> actions;
  final Widget? leadingFooter;

  final double width;

  /// Invoked by `⌘↩` / `Ctrl↩`. Wire this to the same callback as the
  /// primary footer button.
  final VoidCallback? onSubmit;

  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.actions = const [],
    this.leadingFooter,
    this.width = DialogWidth.medium,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    Widget content = Container(
      width: width,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: Radii.xlAll,
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.xl,
              Spacing.xl,
              Spacing.md,
              Spacing.lg,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(Spacing.sm),
                    decoration: BoxDecoration(
                      color:
                          (iconColor ?? colors.accent).withValues(alpha: 0.15),
                      borderRadius: Radii.mdAll,
                    ),
                    child: Icon(
                      icon,
                      size: IconSizes.lg,
                      color: iconColor ?? colors.accent,
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      if (subtitle != null) ...[
                        const SizedBox(height: Spacing.xxs),
                        Text(subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                IconButton(
                  icon: const Icon(Icons.close, size: IconSizes.lg),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.xl),
              child: child,
            ),
          ),

          // Footer
          if (actions.isNotEmpty || leadingFooter != null) ...[
            Divider(height: 1, color: colors.divider),
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Row(
                children: [
                  if (leadingFooter != null) leadingFooter!,
                  const Spacer(),
                  if (onSubmit != null) ...[
                    const KeycapGroup(['⌘', '↩']),
                    const SizedBox(width: Spacing.md),
                  ],
                  ...actions.expand(
                    (a) => [a, const SizedBox(width: Spacing.sm)],
                  ),
                ]..removeLast(),
              ),
            ),
          ],
        ],
      ),
    );

    if (onSubmit != null) {
      content = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, meta: true):
              onSubmit!,
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              onSubmit!,
        },
        child: Focus(autofocus: false, child: content),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(Spacing.xxl),
      child: content,
    );
  }
}

/// A labelled form row used inside [AppDialog] bodies.
class DialogField extends StatelessWidget {
  final String label;
  final bool required;
  final String? helperText;
  final Widget child;

  const DialogField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
            if (required) ...[
              const SizedBox(width: Spacing.xs),
              Text(
                '*',
                style:
                    theme.textTheme.labelMedium?.copyWith(color: colors.danger),
              ),
            ],
          ],
        ),
        const SizedBox(height: Spacing.sm - 2),
        child,
        if (helperText != null) ...[
          const SizedBox(height: Spacing.xs + 2),
          Text(helperText!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// A titled group of related fields inside a long form.
class DialogSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;

  const DialogSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: IconSizes.sm, color: colors.textTertiary),
              const SizedBox(width: Spacing.sm - 2),
            ],
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: colors.textTertiary),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(child: Divider(height: 1, color: colors.divider)),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        child,
      ],
    );
  }
}
