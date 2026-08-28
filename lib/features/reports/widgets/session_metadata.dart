import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/classification_style.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/core/widgets/entity_chip.dart';
import 'package:workpulse/core/widgets/status_badge.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';

enum SessionMetadataField {
  project,
  category,
  classification,
  timesheetCode,
  tags,
  people,
  attributes,
}

/// The chip row that says what a session *was* — the same set, in the same
/// order, wherever a session is listed.
///
/// Three screens grew their own subsets of this (Time Log had project and
/// category, the Work Items inspector had people, Time Notes had project,
/// category and tags), which is why the same session read differently
/// depending on where you looked at it.
class SessionMetadataChips extends ConsumerWidget {
  final SessionExportRecord record;
  final TimesheetCodeResolution? code;

  /// Fields already stated by the surrounding container, so they are not
  /// repeated on every row inside it. See Time Notes promotion rule.
  final Set<SessionMetadataField> omit;

  /// Renders an explicit muted "Uncategorized" chip when the session has no
  /// category. On by default: an unclassified session is the thing the user
  /// is looking for.
  final bool showUnclassified;

  final bool dense;

  const SessionMetadataChips({
    super.key,
    required this.record,
    this.code,
    this.omit = const {},
    this.showUnclassified = true,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final chips = <Widget>[];

    // 1. Project
    if (!omit.contains(SessionMetadataField.project) &&
        record.project != null) {
      chips.add(
        _constrained(
          EntityChip(
            label: record.project!.name,
            color: ColorUtils.parseHex(record.project!.colorHex),
            plain: dense,
          ),
        ),
      );
    }

    // 2. Category
    if (!omit.contains(SessionMetadataField.category)) {
      if (record.category != null) {
        chips.add(
          _constrained(
            EntityChip(
              label: record.category!.name,
              icon: IconUtils.getIcon(record.category!.iconName),
              plain: dense,
            ),
          ),
        );
      } else if (showUnclassified) {
        chips.add(
          _constrained(
            EntityChip(
              label: 'Uncategorized',
              icon: Icons.help_outline,
              color: colors.textTertiary,
              plain: dense,
            ),
          ),
        );
      }
    }

    // 3. Classification
    if (!omit.contains(SessionMetadataField.classification)) {
      final isNone = record.classification == FinancialClassification.none;
      if (!isNone || showUnclassified) {
        final label =
            '${record.classification.label}${record.classificationIsOverride ? '*' : ''}';
        Widget badge = StatusBadge(
          label: label,
          icon: record.classification.icon,
          color: record.classification.colorOf(context),
          emphasis: false,
          outlined: dense,
        );
        if (record.classificationIsOverride) {
          badge = Tooltip(
            message: 'Set on this session, not inherited from the work item',
            child: badge,
          );
        }
        chips.add(_constrained(badge));
      }
    }

    // 4. Timesheet Code
    if (!omit.contains(SessionMetadataField.timesheetCode) &&
        code != null &&
        code!.code != null &&
        code!.code!.isNotEmpty) {
      final codeText = code!.code!;
      Widget chip = EntityChip(
        icon: Icons.receipt_long_outlined,
        label: codeText,
        color: code!.needsAttention ? colors.warning : null,
        plain: dense,
      );
      if (code!.needsAttention) {
        final reason = switch (code!.source) {
          TimesheetCodeSource.unmappedOption =>
            'Unmapped release "${code!.optionLabel ?? ''}" (booked to project default)',
          TimesheetCodeSource.missingCode =>
            'No timesheet code configured for this project',
          TimesheetCodeSource.unknownProject => 'No project assigned',
          _ => 'Timesheet configuration requires attention',
        };
        chip = Tooltip(
          message: reason,
          child: chip,
        );
      }
      chips.add(_constrained(chip));
    }

    // 5. Tags
    if (!omit.contains(SessionMetadataField.tags)) {
      for (final tag in record.tags) {
        chips.add(
          _constrained(
            EntityChip(
              label: '#${tag.name}',
              color: ColorUtils.parseHex(tag.colorHex),
              plain: dense,
            ),
          ),
        );
      }
    }

    // 6. People
    if (!omit.contains(SessionMetadataField.people)) {
      for (final person in record.people) {
        chips.add(
          _constrained(
            EntityChip(
              label: person.name,
              icon: Icons.person,
              plain: true,
            ),
          ),
        );
      }
    }

    // 7. Custom Attributes
    if (!omit.contains(SessionMetadataField.attributes) &&
        record.attributeValues.isNotEmpty) {
      final definitions =
          ref.watch(attributeDefinitionsProvider).value ?? const [];
      final sortedDefs = [...definitions]
        ..sort((a, b) {
          final order = a.displayOrder.compareTo(b.displayOrder);
          if (order != 0) return order;
          return a.name.compareTo(b.name);
        });

      final renderedKeys = <String>{};
      for (final def in sortedDefs) {
        final val = record.attributeValues[def.id];
        if (val != null && val.isNotEmpty) {
          renderedKeys.add(def.id);
          chips.add(
            _constrained(
              EntityChip(
                label: '${def.name}: $val',
                plain: true,
              ),
            ),
          );
        }
      }

      for (final entry in record.attributeValues.entries) {
        if (!renderedKeys.contains(entry.key) && entry.value.isNotEmpty) {
          chips.add(
            _constrained(
              EntityChip(
                label: '${entry.key}: ${entry.value}',
                plain: true,
              ),
            ),
          );
        }
      }
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: Spacing.sm - 2,
      runSpacing: Spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }

  Widget _constrained(Widget child) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: child,
    );
  }
}

/// A session's note, on its own line, never as a chip.
///
/// A note is prose and is the reason most sessions get read at all; squeezing
/// it into a chip row truncated it at the first clause.
class SessionNoteBlock extends StatelessWidget {
  final String note;
  final int maxLines; // 3 in dense lists, unbounded in Time Notes
  final bool callout; // sunken container (Time Notes) vs inline (logs)

  const SessionNoteBlock({
    super.key,
    required this.note,
    this.maxLines = 3,
    this.callout = false,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final theme = Theme.of(context);

    if (callout) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: Radii.mdAll,
          border: Border.all(color: colors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.notes,
                size: IconSizes.xs,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(width: Spacing.xs),
            Expanded(
              child: Text(
                trimmed,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                  color: colors.textPrimary,
                ),
                maxLines: maxLines > 0 ? maxLines : null,
                overflow: maxLines > 0 ? TextOverflow.ellipsis : null,
              ),
            ),
          ],
        ),
      );
    }

    return Tooltip(
      message: trimmed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.notes,
              size: IconSizes.xs,
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Flexible(
            child: Text(
              trimmed,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
