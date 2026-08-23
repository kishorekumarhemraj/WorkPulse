import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// The placeholder shown when a list has nothing to display.
///
/// An empty state should always offer the next step, so [action] is the
/// normal case rather than the exception — a first-run user landing on
/// "No tasks created yet" gets a button that creates one.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  /// Renders inline (smaller, left-aligned) rather than centred in the
  /// viewport — used inside cards and expanded rows.
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.md,
          horizontal: Spacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: Radii.smAll,
        ),
        child: Row(
          children: [
            Icon(icon, size: IconSizes.sm, color: colors.textTertiary),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(title, style: theme.textTheme.bodySmall),
            ),
            if (action != null) ...[
              const SizedBox(width: Spacing.sm),
              action!,
            ],
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: colors.card,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: IconSizes.xl + 6,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: Spacing.xs + 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: Spacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
