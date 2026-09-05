import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/core/widgets/filter_dropdown.dart';
import 'package:workpulse/core/widgets/search_field.dart';
import 'package:workpulse/core/widgets/segmented_control.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';

/// How densely work item rows are drawn.
enum ListDensity { comfortable, compact }

final listDensityProvider = NotifierProvider<ListDensityNotifier, ListDensity>(
  ListDensityNotifier.new,
);

class ListDensityNotifier extends Notifier<ListDensity> {
  @override
  ListDensity build() => ListDensity.comfortable;

  void set(ListDensity density) => state = density;
}

/// Search, filters and density for the Work Items screen.
///
/// Applied filters are also echoed as individually dismissible chips below
/// the controls: previously the only way out of a filter was the all-or-
/// nothing "Clear Filters" button, and a filter set on a collapsed control
/// was easy to forget about.
class WorkItemsToolbar extends ConsumerWidget {
  const WorkItemsToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(workItemFilterProvider);
    final notifier = ref.read(workItemFilterProvider.notifier);
    final density = ref.watch(listDensityProvider);

    final projects = ref.watch(projectsProvider).value ?? [];
    final categories = ref.watch(categoriesProvider).value ?? [];
    final tags = ref.watch(tagsProvider).value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Spacing.sm + 2,
          runSpacing: Spacing.sm + 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SearchField(
              hintText: 'Search work items…',
              initialValue: filter.searchQuery,
              onChanged: notifier.setSearchQuery,
            ),
            AppFilterDropdown<String>(
              placeholder: 'All Projects',
              leadingIcon: Icons.folder_outlined,
              value: filter.projectId,
              onChanged: notifier.setProject,
              options: [
                for (final p in projects)
                  FilterOption(
                    value: p.id,
                    label: p.name,
                    color: ColorUtils.parseHex(p.colorHex),
                  ),
              ],
            ),
            AppFilterDropdown<String>(
              placeholder: 'All Categories',
              leadingIcon: Icons.category_outlined,
              value: filter.categoryId,
              onChanged: notifier.setCategory,
              options: [
                for (final c in categories)
                  FilterOption(
                    value: c.id,
                    label: c.name,
                    icon: IconUtils.getIcon(c.iconName),
                  ),
              ],
            ),
            if (tags.isNotEmpty)
              AppFilterDropdown<String>(
                placeholder: 'All Tags',
                leadingIcon: Icons.label_outline,
                value: filter.tagId,
                onChanged: notifier.setTag,
                options: [
                  for (final t in tags)
                    FilterOption(
                      value: t.id,
                      label: t.name,
                      color: ColorUtils.parseHex(t.colorHex),
                    ),
                ],
              ),
            AppFilterDropdown<PlanFilter>(
              placeholder: 'Any plan',
              leadingIcon: Icons.event_note_outlined,
              value: filter.planFilter == PlanFilter.all
                  ? null
                  : filter.planFilter,
              onChanged: (val) =>
                  notifier.setPlanFilter(val ?? PlanFilter.all),
              options: const [
                FilterOption(
                  value: PlanFilter.overdue,
                  label: 'Overdue',
                ),
                FilterOption(
                  value: PlanFilter.dueToday,
                  label: 'Due today',
                ),
                FilterOption(
                  value: PlanFilter.dueThisWeek,
                  label: 'Due this week',
                ),
                FilterOption(
                  value: PlanFilter.scheduled,
                  label: 'Scheduled',
                ),
                FilterOption(
                  value: PlanFilter.unplanned,
                  label: 'Unplanned',
                ),
                FilterOption(
                  value: PlanFilter.completed,
                  label: 'Completed',
                ),
              ],
            ),
            _ArchivedToggle(
              isOn: filter.includeArchived,
              onToggle: notifier.toggleIncludeArchived,
            ),
            AppSegmentedControl<WorkItemSort>(
              height: ControlSizes.toolbar,
              selected: filter.sort,
              onChanged: (val) => notifier.setSort(val),
              options: const [
                SegmentOption(
                  value: WorkItemSort.recent,
                  label: 'Recent',
                  icon: Icons.schedule,
                ),
                SegmentOption(
                  value: WorkItemSort.dueDate,
                  label: 'Due date',
                  icon: Icons.event,
                ),
                SegmentOption(
                  value: WorkItemSort.name,
                  label: 'Name',
                  icon: Icons.sort_by_alpha,
                ),
              ],
            ),
            AppSegmentedControl<ListDensity>(
              height: ControlSizes.toolbar,
              selected: density,
              iconOnly: true,
              onChanged: (value) =>
                  ref.read(listDensityProvider.notifier).set(value),
              options: const [
                SegmentOption(
                  value: ListDensity.comfortable,
                  label: 'Comfortable',
                  icon: Icons.view_agenda_outlined,
                ),
                SegmentOption(
                  value: ListDensity.compact,
                  label: 'Compact',
                  icon: Icons.view_headline,
                ),
              ],
            ),
          ],
        ),
        if (filter.hasActiveFilters) ...[
          const SizedBox(height: Spacing.md),
          _ActiveFilterChips(
            filter: filter,
            projects: {for (final p in projects) p.id: p.name},
            categories: {for (final c in categories) c.id: c.name},
            tags: {for (final t in tags) t.id: t.name},
          ),
        ],
      ],
    );
  }
}

class _ArchivedToggle extends StatelessWidget {
  final bool isOn;
  final VoidCallback onToggle;

  const _ArchivedToggle({required this.isOn, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Material(
      color: isOn ? colors.warningSubtle : colors.field,
      borderRadius: Radii.mdAll,
      child: InkWell(
        onTap: onToggle,
        borderRadius: Radii.mdAll,
        child: Container(
          height: ControlSizes.toolbar,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          decoration: BoxDecoration(
            borderRadius: Radii.mdAll,
            border: Border.all(
              color: isOn
                  ? colors.warning.withValues(alpha: Alphas.strong)
                  : colors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOn ? Icons.check_box : Icons.check_box_outline_blank,
                size: IconSizes.sm,
                color: isOn ? colors.warning : colors.textSecondary,
              ),
              const SizedBox(width: Spacing.sm - 2),
              Text(
                'Include Archived',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isOn ? colors.warning : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterChips extends ConsumerWidget {
  final WorkItemFilter filter;
  final Map<String, String> projects;
  final Map<String, String> categories;
  final Map<String, String> tags;

  const _ActiveFilterChips({
    required this.filter,
    required this.projects,
    required this.categories,
    required this.tags,
  });

  String _planFilterLabel(PlanFilter pf) {
    switch (pf) {
      case PlanFilter.all:
        return '';
      case PlanFilter.overdue:
        return 'Plan: Overdue';
      case PlanFilter.dueToday:
        return 'Plan: Due today';
      case PlanFilter.dueThisWeek:
        return 'Plan: Due this week';
      case PlanFilter.scheduled:
        return 'Plan: Scheduled';
      case PlanFilter.unplanned:
        return 'Plan: Unplanned';
      case PlanFilter.completed:
        return 'Plan: Completed';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final notifier = ref.read(workItemFilterProvider.notifier);

    final chips = <Widget>[
      if (filter.searchQuery.isNotEmpty)
        _Chip(
          label: 'Search: "${filter.searchQuery}"',
          onRemove: () => notifier.setSearchQuery(''),
        ),
      if (filter.projectId != null)
        _Chip(
          label: 'Project: ${projects[filter.projectId] ?? 'Unknown'}',
          onRemove: () => notifier.setProject(null),
        ),
      if (filter.categoryId != null)
        _Chip(
          label: 'Category: ${categories[filter.categoryId] ?? 'Unknown'}',
          onRemove: () => notifier.setCategory(null),
        ),
      if (filter.tagId != null)
        _Chip(
          label: 'Tag: ${tags[filter.tagId] ?? 'Unknown'}',
          onRemove: () => notifier.setTag(null),
        ),
      if (filter.planFilter != PlanFilter.all)
        _Chip(
          label: _planFilterLabel(filter.planFilter),
          onRemove: () => notifier.setPlanFilter(PlanFilter.all),
        ),
      if (filter.includeArchived)
        _Chip(
          label: 'Including archived',
          onRemove: notifier.toggleIncludeArchived,
        ),
    ];

    return Row(
      children: [
        Text(
          'Filtered by',
          style:
              theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Wrap(
            spacing: Spacing.sm - 2,
            runSpacing: Spacing.xs,
            children: chips,
          ),
        ),
        TextButton.icon(
          onPressed: notifier.reset,
          icon: const Icon(Icons.clear_all, size: IconSizes.sm),
          label: const Text('Clear Filters'),
          style: TextButton.styleFrom(
            foregroundColor: colors.danger,
            minimumSize: const Size(0, 28),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _Chip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.only(
        left: Spacing.sm,
        right: Spacing.xs,
        top: Spacing.xxs,
        bottom: Spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.accentSubtle,
        borderRadius: Radii.smAll,
        border:
            Border.all(color: colors.accent.withValues(alpha: Alphas.muted)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: colors.accent),
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Tooltip(
            message: 'Remove filter',
            child: InkWell(
              onTap: onRemove,
              borderRadius: Radii.pillAll,
              child:
                  Icon(Icons.close, size: IconSizes.xs, color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
