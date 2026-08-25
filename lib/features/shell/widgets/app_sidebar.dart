import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/dashboard/providers/dashboard_provider.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/shell/models/shell_nav_tab.dart';
import 'package:workpulse/features/shell/widgets/sidebar_footer.dart';
import 'package:workpulse/features/shell/widgets/sidebar_header.dart';
import 'package:workpulse/features/shell/widgets/sidebar_nav_item.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';

/// Live item counts shown beside each nav destination.
final _navCountProviders = <ShellNavTab, Provider<int?>>{
  ShellNavTab.patterns:
      Provider((r) => r.watch(workPatternReportProvider).value?.insights.length),
  ShellNavTab.history:
      Provider((r) => r.watch(sessionHistoryProvider).value?.length),
  ShellNavTab.tasks: Provider((r) => r.watch(workItemsProvider).value?.length),
  ShellNavTab.projects:
      Provider((r) => r.watch(projectsProvider).value?.length),
  ShellNavTab.categories:
      Provider((r) => r.watch(categoriesProvider).value?.length),
  ShellNavTab.tags: Provider((r) => r.watch(tagsProvider).value?.length),
  ShellNavTab.people: Provider((r) => r.watch(peopleProvider).value?.length),
  ShellNavTab.attributes:
      Provider((r) => r.watch(attributeDefinitionsProvider).value?.length),
};

/// The main navigation rail.
///
/// Destinations are grouped rather than presented as one flat list of eight,
/// and the whole rail collapses to icons for users who want the width back.
class AppSidebar extends ConsumerWidget {
  final Workspace workspace;
  final String hotKeyLabel;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onQuickCapture;
  final VoidCallback? onEditShortcut;
  final Duration? idleThreshold;
  final ValueChanged<Duration> onIdleThresholdChanged;

  const AppSidebar({
    super.key,
    required this.workspace,
    required this.hotKeyLabel,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onQuickCapture,
    required this.onEditShortcut,
    required this.idleThreshold,
    required this.onIdleThresholdChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final activeTab = ref.watch(activeNavTabProvider);
    final isCollapsed = ref.watch(sidebarCollapsedProvider);

    final targetWidth = isCollapsed
        ? ControlSizes.sidebarCollapsed
        : ControlSizes.sidebarExpanded;

    return AnimatedContainer(
      duration: Motion.duration(context, Motion.base),
      curve: Motion.curve,
      width: targetWidth,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.divider)),
      ),
      // The container's width animates but its contents switch layout
      // instantly, so mid-animation the rows are wider than the box. Lay the
      // contents out at the target width and clip the overflow, which makes
      // the rail slide rather than reflow on every frame.
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: targetWidth,
          maxWidth: targetWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SidebarHeader(
                workspace: workspace,
                isCollapsed: isCollapsed,
                hotKeyLabel: hotKeyLabel,
                onQuickCapture: onQuickCapture,
                onToggleCollapse: () =>
                    ref.read(sidebarCollapsedProvider.notifier).toggle(),
              ),
              Divider(height: 1, color: colors.divider),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.sm,
                  ),
                  children: [
                    for (final group in ShellNavGroup.values) ...[
                      _GroupLabel(label: group.label, isCollapsed: isCollapsed),
                      for (final tab in tabsInGroup(group))
                        SidebarNavItem(
                          tab: tab,
                          isSelected: activeTab == tab,
                          isCollapsed: isCollapsed,
                          countProvider: _navCountProviders[tab],
                          onTap: () => ref
                              .read(activeNavTabProvider.notifier)
                              .setTab(tab),
                        ),
                      const SizedBox(height: Spacing.md),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: colors.divider),
              SidebarFooter(
                themeMode: themeMode,
                onThemeModeChanged: onThemeModeChanged,
                hotKeyLabel: hotKeyLabel,
                onEditShortcut: onEditShortcut,
                idleThreshold: idleThreshold,
                onIdleThresholdChanged: onIdleThresholdChanged,
                isCollapsed: isCollapsed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String label;
  final bool isCollapsed;

  const _GroupLabel({required this.label, required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Collapsed, a text heading would not fit; a rule keeps the grouping
    // legible without it.
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.sm,
        ),
        child: Divider(height: 1, color: colors.divider),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md - 2,
        Spacing.sm,
        Spacing.md - 2,
        Spacing.xs + 2,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: colors.textTertiary),
      ),
    );
  }
}
