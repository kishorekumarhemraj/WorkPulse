import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/entity_chip.dart';
import 'package:workpulse/core/widgets/hoverable.dart';
import 'package:workpulse/core/widgets/status_badge.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/features/reports/widgets/session_metadata.dart';

/// One logged session inside a day group.
///
/// Replaces the previous fixed-width Row (which reserved 140px for the date
/// alone and squashed everything else as the window narrowed). The date now
/// lives on the group header, so the row only carries what varies.
///
/// Edit and delete are revealed on hover, so a long log reads as data rather
/// than as a wall of buttons — both remain reachable by keyboard and are
/// always present for assistive tech.
class SessionRow extends StatelessWidget {
  final SessionExportRecord record;
  final TimesheetCodeResolver codes;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isFirst;
  final bool isLast;

  const SessionRow({
    super.key,
    required this.record,
    this.codes = const TimesheetCodeResolver(),
    required this.onEdit,
    required this.onDelete,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');

    final session = record.session;
    final start = session.startTime.toLocal();
    final end = session.endTime?.toLocal();
    final isRunning = end == null;
    final projectColor = ColorUtils.parseHex(record.project?.colorHex);
    final codeResolution = codes.resolveFor(
      project: record.project,
      attributeOptionIds: record.attributeOptionIds,
    );

    return Hoverable(
      cursor: SystemMouseCursors.click,
      builder: (context, isHovered) {
        return Material(
          color: isHovered ? colors.hover : Colors.transparent,
          child: InkWell(
            onTap: onEdit,
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline gutter: a marker per session, tinted with the
                  // project's colour, giving the day a visual spine.
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SizedBox(
                      width: 14,
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isRunning ? colors.successFill : projectColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.surface, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),

                  // Clock range
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SizedBox(
                      width: 104,
                      child: Text(
                        isRunning
                            ? '${timeFormat.format(start)} – now'
                            : '${timeFormat.format(start)} – ${timeFormat.format(end)}',
                        style: AppTypography.numeric(
                          fontSize: 12,
                          color:
                              isRunning ? colors.success : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),

                  // Task, metadata and notes
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                record.workItem.name,
                                style: theme.textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isRunning) ...[
                              const SizedBox(width: Spacing.sm),
                              const StatusBadge(
                                label: 'Active',
                                icon: Icons.play_arrow,
                                tone: BadgeTone.success,
                                emphasis: true,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: Spacing.xs),
                        SessionMetadataChips(
                          record: record,
                          code: codeResolution,
                        ),
                        if ((session.notes ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: Spacing.xs),
                          SessionNoteBlock(
                            note: session.notes!.trim(),
                            maxLines: 3,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.md),

                  if (record.idleDuration.inSeconds > 0) ...[
                    MetricChip(
                      value:
                          '−${TimerService.formatDuration(record.idleDuration, includeSeconds: false)}',
                      icon: Icons.nightlight_round,
                      color: colors.warning,
                    ),
                    const SizedBox(width: Spacing.sm),
                  ],

                  Text(
                    TimerService.formatDuration(
                      record.netActiveDuration,
                      includeSeconds: true,
                    ),
                    style: AppTypography.numeric(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isRunning ? colors.success : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),

                  // Row actions. Kept in the tree at all times — hiding them
                  // outright would take them out of the tab order and away
                  // from screen readers — and only faded until hover.
                  AnimatedOpacity(
                    opacity: isHovered ? 1 : 0,
                    duration: Motion.duration(context, Motion.fast),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: IconSizes.md,
                          ),
                          tooltip: 'Edit session',
                          visualDensity: VisualDensity.compact,
                          onPressed: onEdit,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: IconSizes.md,
                          ),
                          tooltip: 'Delete session',
                          visualDensity: VisualDensity.compact,
                          color: colors.danger,
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
