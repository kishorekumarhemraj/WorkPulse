import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// What a transient message is telling the user.
enum SnackTone { success, failure, info }

/// The app's transient message.
///
/// Nineteen call sites each hand-built a `SnackBar`: different icons, three
/// different durations, some with a close button and some without, and all of
/// them painting a saturated fill with hardcoded `Colors.white` text. That
/// last part is the reason this exists rather than a style guide note — white
/// on the *light* palette's success green does not clear contrast, and the
/// palette's own direction is that colour belongs to data, not chrome.
///
/// Here the surface comes from the theme's `snackBarTheme` and the tone is
/// carried by a single coloured icon, which reads correctly in both themes.
class AppSnackBar {
  final String message;
  final SnackTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppSnackBar({
    required this.message,
    this.tone = SnackTone.info,
    this.actionLabel,
    this.onAction,
  });

  const AppSnackBar.success({
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : tone = SnackTone.success;

  const AppSnackBar.failure({
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : tone = SnackTone.failure;

  /// Failures stay up longer: they usually carry an error string the user may
  /// want to read or copy.
  Duration get duration => tone == SnackTone.failure
      ? const Duration(seconds: 6)
      : const Duration(seconds: 4);

  IconData get icon => switch (tone) {
        SnackTone.success => Icons.check_circle_outline,
        SnackTone.failure => Icons.error_outline,
        SnackTone.info => Icons.info_outline,
      };

  Color accentOf(WorkPulseColors colors) => switch (tone) {
        SnackTone.success => colors.success,
        SnackTone.failure => colors.danger,
        SnackTone.info => colors.accent,
      };

  SnackBar build(BuildContext context) {
    final colors = context.colors;
    final accent = accentOf(colors);

    return SnackBar(
      duration: duration,
      content: Row(
        children: [
          Icon(icon, size: IconSizes.md, color: accent),
          const SizedBox(width: Spacing.sm + 2),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
      action: actionLabel == null || onAction == null
          ? null
          : SnackBarAction(
              label: actionLabel!,
              textColor: accent,
              onPressed: onAction!,
            ),
    );
  }
}

extension AppSnackBarMessenger on ScaffoldMessengerState {
  /// Shows [snack], replacing anything already on screen so a burst of
  /// messages does not queue up behind one another.
  void showAppSnackBar(AppSnackBar snack) {
    clearSnackBars();
    showSnackBar(snack.build(context));
  }
}
