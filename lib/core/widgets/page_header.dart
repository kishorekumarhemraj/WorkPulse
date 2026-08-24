import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// The title block at the top of every screen.
///
/// Replaces eight copy-pasted header blocks that had drifted to different
/// title sizes (24 on Work Items and Projects, 22 on Dashboard and Time Log)
/// and different subtitle sizes (12 vs 13).
///
/// [toolbar] sits on its own row beneath the title and is where search and
/// filters go, so the primary action in [actions] never competes with them
/// for space as the window narrows.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? toolbar;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.toolbar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 1150;
            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: Spacing.xs),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: Spacing.md),
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: actions,
                    ),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: Spacing.xs),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: Spacing.lg),
                  Wrap(
                    spacing: Spacing.sm,
                    runSpacing: Spacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actions,
                  ),
                ],
              ],
            );
          },
        ),
        if (toolbar != null) ...[
          const SizedBox(height: Spacing.lg),
          toolbar!,
        ],
      ],
    );
  }
}

/// The standard page shell: uniform padding, header, then content.
class PageScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? toolbar;
  final Widget child;

  /// Set when the page scrolls as a whole rather than containing its own
  /// scrolling list.
  final bool scrollable;

  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.toolbar,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final header = PageHeader(
      title: title,
      subtitle: subtitle,
      actions: actions,
      toolbar: toolbar,
    );

    if (scrollable) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: Spacing.xxl),
            child,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: Spacing.xl),
          Expanded(child: child),
        ],
      ),
    );
  }
}
