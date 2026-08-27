import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/projects/views/project_form_dialog.dart';
import 'package:workpulse/features/timesheet/widgets/timesheet_table.dart';

class _AttentionItem {
  final String projectId;
  final String projectName;
  final String? optionLabel;
  final TimesheetCodeSource source;
  final Duration duration;

  const _AttentionItem({
    required this.projectId,
    required this.projectName,
    this.optionLabel,
    required this.source,
    required this.duration,
  });
}

/// A card warning about unmapped options, missing default codes, or unknown
/// projects on the Time Sheet.
///
/// Gives direct links to the project form to fix configuration gaps.
class TimesheetAttentionCard extends ConsumerWidget {
  final List<TimesheetCodeRow> rows;
  final TimesheetHoursBasis basis;

  const TimesheetAttentionCard({
    super.key,
    required this.rows,
    required this.basis,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final items = <_AttentionItem>[];
    for (final r in rows) {
      for (final c in r.contributions) {
        if (c.source.needsAttention) {
          items.add(_AttentionItem(
            projectId: c.projectId,
            projectName: c.projectName,
            optionLabel: c.optionLabel,
            source: c.source,
            duration: c.split(basis).total,
          ));
        }
      }
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final projectsAsync = ref.watch(projectsProvider);
    final allProjects = projectsAsync.value ?? [];

    return AppCard(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: IconSizes.md,
                color: colors.warning,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                'Timesheet Attention Items',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      _formatMessage(item),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (item.projectId.isNotEmpty) ...[
                    const SizedBox(width: Spacing.sm),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm,
                          vertical: Spacing.xs,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        final proj = allProjects
                            .where((p) => p.id == item.projectId)
                            .firstOrNull;
                        if (proj != null) {
                          ProjectFormDialog.show(context, project: proj);
                        }
                      },
                      child: const Text('Edit Project'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMessage(_AttentionItem item) {
    final formattedHours = '${formatTimesheetHours(item.duration)}h';
    switch (item.source) {
      case TimesheetCodeSource.unmappedOption:
        if (item.optionLabel != null && item.optionLabel!.isNotEmpty) {
          return '$formattedHours in "${item.projectName}" has release "${item.optionLabel}" with no mapped code (booked to project default)';
        }
        return '$formattedHours in "${item.projectName}" has an unmapped release (booked to project default)';
      case TimesheetCodeSource.missingCode:
        return '$formattedHours in "${item.projectName}" has no timesheet code configured';
      case TimesheetCodeSource.unknownProject:
        return '$formattedHours tracked without a project';
      default:
        return '$formattedHours in "${item.projectName}" requires attention';
    }
  }
}

extension on TimesheetCodeContribution {
  ClassificationSplit split(TimesheetHoursBasis basis) =>
      basis == TimesheetHoursBasis.net ? net : gross;
}
