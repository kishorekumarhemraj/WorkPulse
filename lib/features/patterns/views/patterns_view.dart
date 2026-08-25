import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/core/widgets/app_snack_bar.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/core/widgets/page_header.dart';
import 'package:workpulse/core/widgets/segmented_control.dart';
import 'package:workpulse/core/widgets/skeleton_loader.dart';
import 'package:workpulse/core/widgets/status_badge.dart';
import 'package:workpulse/domain/models/work_pattern_model.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/dashboard/providers/dashboard_provider.dart';

/// The dedicated Patterns & Signals page.
///
/// Answers the question the user actually came back for: which of those hours
/// were spent on something that did not need them, what recurs often enough to
/// hand over, and what is quietly slipping.
class PatternsView extends ConsumerWidget {
  const PatternsView({super.key});

  String _formatSubtitle(PatternWindow window, WorkPatternReport? report) {
    if (report == null) {
      return 'Scanning ${window.label.toLowerCase()}…';
    }
    if (!report.hasData) {
      return 'Nothing tracked in the ${window.days} days scanned';
    }
    final days = report.rhythm.trackedDayCount;
    final active = TimerService.formatDuration(
      report.totalActive,
      compact: true,
      includeSeconds: false,
    );
    return '${report.sessionCount} sessions over $days tracked '
        '${days == 1 ? 'day' : 'days'} · $active active';
  }

  void _copyFindings(BuildContext context, WorkPatternReport report) {
    final buffer = StringBuffer()
      ..writeln('# Work patterns — ${report.lookback.label}')
      ..writeln();

    for (final action in InsightAction.values) {
      final insights = report.forAction(action);
      if (insights.isEmpty) continue;

      buffer.writeln('## ${action.label}');
      for (final insight in insights) {
        buffer
          ..writeln('- **${insight.title}**')
          ..writeln('  - ${insight.finding}')
          ..writeln('  - → ${insight.recommendation}');
      }
      buffer.writeln();
    }

    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    ScaffoldMessenger.of(context).showAppSnackBar(
      const AppSnackBar.success(message: 'Findings copied to clipboard'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final reportAsync = ref.watch(workPatternReportProvider);
    final window = ref.watch(patternWindowProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: PageScaffold(
        scrollable: true,
        title: 'Patterns & Signals',
        subtitle: _formatSubtitle(window, reportAsync.value),
        actions: [
          AppSegmentedControl<PatternWindow>(
            selected: window,
            onChanged: (next) =>
                ref.read(patternWindowProvider.notifier).setWindow(next),
            height: ControlSizes.toolbar,
            options: const [
              SegmentOption(value: PatternWindow.twoWeeks, label: '14 days'),
              SegmentOption(value: PatternWindow.oneMonth, label: '30 days'),
              SegmentOption(value: PatternWindow.oneQuarter, label: '90 days'),
            ],
          ),
          if (reportAsync.value != null && reportAsync.value!.hasInsights)
            Tooltip(
              message: 'Copy these findings as Markdown',
              child: ElevatedButton.icon(
                onPressed: () => _copyFindings(context, reportAsync.value!),
                icon: const Icon(Icons.copy_all_outlined, size: IconSizes.md),
                label: const Text('Copy Findings'),
              ),
            ),
          IconButton(
            onPressed: () => ref.invalidate(workPatternReportProvider),
            icon: const Icon(Icons.refresh, size: IconSizes.md),
            tooltip: 'Refresh pattern scan',
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
        child: reportAsync.when(
          skipLoadingOnReload: true,
          loading: () => const _PanelSkeleton(),
          error: (err, _) => ErrorState(
            title: 'Could not scan for patterns',
            error: err,
            onRetry: () => ref.invalidate(workPatternReportProvider),
          ),
          data: (report) => _PanelBody(report: report),
        ),
      ),
    );
  }
}

class _PanelBody extends StatelessWidget {
  final WorkPatternReport report;

  const _PanelBody({required this.report});

  @override
  Widget build(BuildContext context) {
    if (!report.hasData) {
      return const EmptyState(
        icon: Icons.insights_outlined,
        title: 'Nothing to read yet',
        message: 'Track a few days of work and this fills in on its own — '
            'patterns need more than one day to be patterns.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RhythmStrip(rhythm: report.rhythm),
        const SizedBox(height: Spacing.xl),
        if (!report.hasInsights)
          const EmptyState(
            icon: Icons.check_circle_outline,
            title: 'No patterns worth flagging',
            message: 'Nothing in this window is fragmented, repeating without '
                'need, or going quiet. Keep tracking — this is where it will '
                'show up when it changes.',
          )
        else
          _InsightLanes(report: report),
      ],
    );
  }
}

/// The shape of the working day, as context for everything below it.
class _RhythmStrip extends StatelessWidget {
  final FocusRhythm rhythm;

  const _RhythmStrip({required this.rhythm});

  static String _hourLabel(int hour) {
    final normalised = hour % 24;
    if (normalised == 0) return '12am';
    if (normalised == 12) return '12pm';
    if (normalised < 12) return '${normalised}am';
    return '${normalised - 12}pm';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final peak = rhythm.peakFocusHours.isEmpty
        ? '—'
        : '${_hourLabel(rhythm.peakFocusHours.first)}'
            '–${_hourLabel(rhythm.peakFocusHours.last + 1)}';

    final stats = <_RhythmStat>[
      _RhythmStat(
        label: 'Deep work',
        value: '${(rhythm.deepWorkShare * 100).round()}%',
        detail: TimerService.formatDuration(
          rhythm.deepWorkTotal,
          compact: true,
          includeSeconds: false,
        ),
        icon: Icons.bolt,
        color: colors.success,
      ),
      _RhythmStat(
        label: 'Longest stretch',
        value: TimerService.formatDuration(
          rhythm.longestUnbrokenBlock,
          compact: true,
          includeSeconds: false,
        ),
        detail: 'unbroken',
        icon: Icons.trending_up,
        color: colors.accent,
      ),
      _RhythmStat(
        label: 'Sessions a day',
        value: rhythm.switchesPerTrackedDay.toStringAsFixed(1),
        detail: 'median '
            '${TimerService.formatDuration(rhythm.medianSessionLength, compact: true, includeSeconds: false)}',
        icon: Icons.swap_horiz,
        color: colors.warning,
      ),
      _RhythmStat(
        label: 'Focus window',
        value: peak,
        detail: 'your best blocks',
        icon: Icons.schedule,
        color: colors.info,
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.all(Spacing.lg + 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= Breakpoints.medium
              ? 4
              : constraints.maxWidth >= Breakpoints.compact
                  ? 2
                  : 1;
          const gap = Spacing.lg;
          final width =
              (constraints.maxWidth - (gap * (columns - 1))) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final stat in stats) SizedBox(width: width, child: stat),
            ],
          );
        },
      ),
    );
  }
}

class _RhythmStat extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  const _RhythmStat({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: IconSizes.lg, color: color),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: Spacing.xxs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: AppTypography.numeric(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: Spacing.xs + 2),
                    Text(detail, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Reclaim / Delegate / Plan, side by side when there is room.
class _InsightLanes extends StatelessWidget {
  final WorkPatternReport report;

  const _InsightLanes({required this.report});

  @override
  Widget build(BuildContext context) {
    final lanes = <_Lane>[
      for (final action in InsightAction.values)
        if (report.forAction(action).isNotEmpty)
          _Lane(action, report.forAction(action)),
    ];

    Widget lane(_Lane data) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _LaneHeader(action: data.action, count: data.insights.length),
            const SizedBox(height: Spacing.md),
            for (var i = 0; i < data.insights.length; i++) ...[
              if (i > 0) const SizedBox(height: Spacing.md),
              _InsightCard(insight: data.insights[i]),
            ],
          ],
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Four lanes in one row need real width; below that they wrap two-up
        // and then stack. A column narrower than about 300px turns every
        // finding into a ladder of two-word lines.
        final fits = switch (constraints.maxWidth) {
          >= Breakpoints.wide => 4,
          >= Breakpoints.medium => 2,
          _ => 1,
        };
        final columns = fits > lanes.length ? lanes.length : fits;

        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < lanes.length; i++) ...[
                if (i > 0) const SizedBox(height: Spacing.xl),
                lane(lanes[i]),
              ],
            ],
          );
        }

        final rows = <List<_Lane>>[
          for (var i = 0; i < lanes.length; i += columns)
            lanes.sublist(
              i,
              i + columns > lanes.length ? lanes.length : i + columns,
            ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: Spacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) const SizedBox(width: Spacing.lg),
                    // A short final row keeps the column widths of the rows
                    // above it rather than stretching to fill.
                    Expanded(
                      child: i < rows[r].length
                          ? lane(rows[r][i])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Lane {
  final InsightAction action;
  final List<WorkPatternInsight> insights;

  const _Lane(this.action, this.insights);
}

class _LaneHeader extends StatelessWidget {
  final InsightAction action;
  final int count;

  const _LaneHeader({required this.action, required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final tone = _toneFor(action, colors);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(_iconFor(action), size: IconSizes.md, color: tone),
            const SizedBox(width: Spacing.sm),
            Text(
              action.label,
              style: theme.textTheme.titleMedium?.copyWith(color: tone),
            ),
            const SizedBox(width: Spacing.sm),
            StatusBadge(label: '$count', color: tone),
          ],
        ),
        const SizedBox(height: Spacing.xxs),
        Text(action.description, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _InsightCard extends StatefulWidget {
  final WorkPatternInsight insight;

  const _InsightCard({required this.insight});

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard> {
  bool _showEvidence = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final insight = widget.insight;
    final tone = _toneFor(insight.action, colors);

    final stripe = insight.colorHex == null
        ? tone
        : ColorUtils.parseHex(insight.colorHex, defaultColor: tone);

    return AppCard(
      padding: const EdgeInsets.all(Spacing.lg),
      leadingStripe: stripe,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  insight.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: colors.textPrimary),
                ),
              ),
              if (insight.timeInvolved > Duration.zero) ...[
                const SizedBox(width: Spacing.sm),
                StatusBadge(
                  label: TimerService.formatDuration(
                    insight.timeInvolved,
                    compact: true,
                    includeSeconds: false,
                  ),
                  icon: Icons.schedule,
                  // Severity grades a problem. On a Continue card the hours
                  // are the good news, so they are not graded at all.
                  tone: insight.action == InsightAction.sustain
                      ? BadgeTone.success
                      : _severityTone(insight.severity),
                ),
              ],
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            insight.finding,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: Spacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: Radii.smAll,
              border: Border(left: BorderSide(color: tone, width: 2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: IconSizes.sm, color: tone),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    insight.recommendation,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textPrimary, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          if (insight.evidence.isNotEmpty) ...[
            const SizedBox(height: Spacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showEvidence = !_showEvidence),
                icon: Icon(
                  _showEvidence ? Icons.expand_less : Icons.expand_more,
                  size: IconSizes.sm,
                ),
                label: Text(_showEvidence ? 'Hide numbers' : 'Show numbers'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                ),
              ),
            ),
            if (_showEvidence)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.xs),
                child: Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: [
                    for (final item in insight.evidence)
                      _EvidenceChip(evidence: item),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceChip extends StatelessWidget {
  final InsightEvidence evidence;

  const _EvidenceChip({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: Radii.smAll,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(evidence.label, style: theme.textTheme.bodySmall),
          const SizedBox(width: Spacing.xs + 2),
          Text(
            evidence.value,
            style: AppTypography.numeric(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelSkeleton extends StatelessWidget {
  const _PanelSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget card() => Container(
          height: 148,
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.xlAll,
            border: Border.all(color: colors.divider),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 200, height: 13),
              SizedBox(height: Spacing.md),
              Skeleton(width: double.infinity, height: 11),
              SizedBox(height: Spacing.sm),
              Skeleton(width: 240, height: 11),
              SizedBox(height: Spacing.lg),
              Skeleton(width: double.infinity, height: 34),
            ],
          ),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= Breakpoints.medium ? 3 : 1;
        const gap = Spacing.lg;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < columns; i++)
              SizedBox(width: width, child: card()),
          ],
        );
      },
    );
  }
}

Color _toneFor(InsightAction action, WorkPulseColors colors) =>
    switch (action) {
      InsightAction.sustain => colors.success,
      InsightAction.reclaim => colors.warning,
      InsightAction.delegate => colors.info,
      InsightAction.plan => colors.accent,
    };

IconData _iconFor(InsightAction action) => switch (action) {
      InsightAction.sustain => Icons.verified_outlined,
      InsightAction.reclaim => Icons.restore,
      InsightAction.delegate => Icons.group_add_outlined,
      InsightAction.plan => Icons.event_available_outlined,
    };

BadgeTone _severityTone(InsightSeverity severity) => switch (severity) {
      InsightSeverity.high => BadgeTone.danger,
      InsightSeverity.notable => BadgeTone.warning,
      InsightSeverity.informational => BadgeTone.neutral,
    };
