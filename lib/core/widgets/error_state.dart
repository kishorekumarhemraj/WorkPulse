import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// Shown when an async load fails.
///
/// Previously these were bare `Text('Error loading X: $error')` lines with no
/// way forward. A failed read from a local SQLite database is almost always
/// transient or fixable, so this always offers a retry that re-runs the
/// provider.
class ErrorState extends StatelessWidget {
  final String title;
  final Object? error;
  final VoidCallback? onRetry;
  final bool compact;

  const ErrorState({
    super.key,
    required this.title,
    this.error,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: colors.dangerSubtle,
          borderRadius: Radii.smAll,
          border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: IconSizes.sm,
              color: colors.danger,
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                error == null ? title : '$title: $error',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: colors.danger),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: colors.danger),
                child: const Text('Retry'),
              ),
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
                color: colors.dangerSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: IconSizes.xl + 6,
                color: colors.danger,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(title, style: theme.textTheme.titleMedium),
            if (error != null) ...[
              const SizedBox(height: Spacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: Spacing.xl),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: IconSizes.md),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
