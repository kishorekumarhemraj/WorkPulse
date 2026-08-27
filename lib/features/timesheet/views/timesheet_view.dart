import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/core/widgets/page_header.dart';
import 'package:workpulse/core/widgets/segmented_control.dart';
import 'package:workpulse/core/widgets/skeleton_loader.dart';
import 'package:workpulse/core/theme/classification_style.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/reports/widgets/reports_range_controls.dart';
import 'package:workpulse/features/timesheet/providers/timesheet_provider.dart';
import 'package:workpulse/features/timesheet/widgets/timesheet_attention_card.dart';
import 'package:workpulse/features/timesheet/widgets/timesheet_code_table.dart';
import 'package:workpulse/features/timesheet/widgets/timesheet_summary.dart';
import 'package:workpulse/features/timesheet/widgets/timesheet_table.dart';

/// Capitalizable against operational hours, for the selected range.
///
/// The screen answers one question — "what do I put on my timesheet?" — so
/// every figure on it is decimal hours, and the CapEx/OpEx split is repeated
/// by project, by task, by category within each classification, and by
/// configurable attribute rather than only in aggregate.
///
/// The classification is the task's, unless a session overrides it. That is
/// what makes the category breakdown worth reading: categories name the kind
/// of work, so "which of my CapEx hours went to meetings" is now a question
/// with an answer.
class TimesheetView extends ConsumerWidget {
  const TimesheetView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selectedRange = ref.watch(reportsTimeRangeProvider);
    final selectedDate = ref.watch(reportsDateProvider);
    final basis = ref.watch(timesheetHoursBasisProvider);
    final timesheetAsync = ref.watch(timesheetDataProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: PageScaffold(
        title: 'Time Sheet',
        subtitle: formatReportsRangeSubtitle(selectedRange, selectedDate),
        actions: [
          const ReportsRangePicker(),
          const ReportsDateStepper(),
          AppSegmentedControl<TimesheetHoursBasis>(
            selected: basis,
            onChanged: (value) =>
                ref.read(timesheetHoursBasisProvider.notifier).setBasis(value),
            options: [
              for (final option in TimesheetHoursBasis.values)
                SegmentOption(
                  value: option,
                  label: '${option.label} hours',
                  tooltip: option.description,
                ),
            ],
          ),
          IconButton(
            onPressed: () => ref.invalidate(sessionHistoryProvider),
            icon: const Icon(Icons.refresh, size: IconSizes.md),
            tooltip: 'Recalculate from the session log',
            style: IconButton.styleFrom(
              minimumSize:
                  const Size(ControlSizes.standard, ControlSizes.standard),
              maximumSize:
                  const Size(ControlSizes.standard, ControlSizes.standard),
              padding: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
            ),
          ),
        ],
        child: timesheetAsync.when(
          loading: () => const SkeletonList(itemCount: 3, itemHeight: 160),
          error: (error, _) => ErrorState(
            title: 'Could not build the time sheet',
            error: error,
            onRetry: () => ref.invalidate(sessionHistoryProvider),
          ),
          data: (data) {
            if (data.isEmpty) {
              return const EmptyState(
                icon: Icons.table_chart_outlined,
                title: 'No tracked time in this period',
                message: 'Track a session against a work item, then come back '
                    'to see how it divides between capitalizable and '
                    'operational work.',
              );
            }

            final hasAttention = data.codeRows.any((r) => r.needsAttention);

            return ListView(
              padding: const EdgeInsets.only(bottom: Spacing.xxl),
              children: [
                TimesheetSummary(
                  total: data.total,
                  basis: basis,
                  sessionCount: data.sessionCount,
                ),
                if (hasAttention) ...[
                  const SizedBox(height: Spacing.xl),
                  TimesheetAttentionCard(
                    rows: data.codeRows,
                    basis: basis,
                  ),
                ],
                const SizedBox(height: Spacing.xl),
                TimesheetCodeTable(
                  rows: data.codeRows,
                  basis: basis,
                ),
                const SizedBox(height: Spacing.xl),
                TimesheetTable(
                  title: 'By project',
                  icon: Icons.folder_outlined,
                  subtitle: 'Where the hours went, and how much of each '
                      'project is capitalizable.',
                  nameColumnLabel: 'Project',
                  rows: data.projectRows,
                  basis: basis,
                ),
                const SizedBox(height: Spacing.xl),
                TimesheetTable(
                  title: 'By work item',
                  icon: Icons.check_circle_outline,
                  subtitle: 'The level the classification is set at, so a '
                      'figure that looks wrong is traceable to the task '
                      'that caused it.',
                  nameColumnLabel: 'Work item',
                  rows: data.taskRows,
                  basis: basis,
                ),
                for (final section in data.categorySections) ...[
                  const SizedBox(height: Spacing.xl),
                  TimesheetTable(
                    title: '${section.classification.label} by category',
                    icon: section.classification.icon,
                    subtitle: _categorySubtitle(section.classification),
                    nameColumnLabel: 'Category',
                    rows: section.rows,
                    basis: basis,
                  ),
                ],
                for (final section in data.attributeSections) ...[
                  const SizedBox(height: Spacing.xl),
                  TimesheetTable(
                    title: 'By ${section.definition.name}',
                    icon: Icons.tune,
                    subtitle: _attributeSubtitle(section.definition),
                    nameColumnLabel: section.definition.name,
                    rows: section.rows,
                    basis: basis,
                  ),
                ],
                if (data.attributeSections.isEmpty) ...[
                  const SizedBox(height: Spacing.xl),
                  const _NoAttributesHint(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static String _categorySubtitle(FinancialClassification classification) {
    return switch (classification) {
      FinancialClassification.capex =>
        'What the capitalizable hours were actually spent doing — coding '
            'against meetings, and everything else.',
      FinancialClassification.opex =>
        'What the operational hours were actually spent doing.',
      FinancialClassification.none =>
        'Hours no task has classified yet. Set a classification on the work '
            'item, or override it on the session.',
    };
  }

  static String _attributeSubtitle(AttributeDefinition definition) {
    final scope = definition.scope == AttributeScope.session
        ? 'Recorded per session.'
        : 'Recorded on the work item.';
    final description = definition.description?.trim();
    if (description == null || description.isEmpty) return scope;
    return '$description · $scope';
  }
}

/// Shown when no attribute is set up to report on, so the screen explains the
/// missing half of itself rather than simply ending after the project table.
class _NoAttributesHint extends StatelessWidget {
  const _NoAttributesHint();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tune, size: IconSizes.lg, color: colors.textTertiary),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No attributes to break down by',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Add a reportable attribute under Attributes — a cost '
                  'centre, a workstream, an epic — and this screen gains a '
                  'CAPEX / OPEX table for each one.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
