import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// A small rendering of a keyboard key, e.g. `⌘K` or `esc`.
///
/// Keyboard shortcuts are only useful if they are discoverable, so every
/// shortcut the app supports is shown next to the control it drives rather
/// than hidden in a help screen.
class Keycap extends StatelessWidget {
  final String label;

  /// Renders against a filled accent background (used inside tinted rows).
  final bool onAccent;

  const Keycap(this.label, {super.key, this.onAccent = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = onAccent ? colors.onAccent : colors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xs + 1,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: onAccent
            ? colors.onAccent.withValues(alpha: Alphas.subtle)
            : colors.surfaceSunken,
        borderRadius: Radii.xsAll,
        border: Border.all(
          color: onAccent
              ? colors.onAccent.withValues(alpha: Alphas.muted)
              : colors.divider,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              letterSpacing: 0.2,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// A row of [Keycap]s, e.g. `⌘` `K`.
class KeycapGroup extends StatelessWidget {
  final List<String> keys;
  final bool onAccent;

  const KeycapGroup(this.keys, {super.key, this.onAccent = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Keycap(keys[i], onAccent: onAccent),
        ],
      ],
    );
  }
}
