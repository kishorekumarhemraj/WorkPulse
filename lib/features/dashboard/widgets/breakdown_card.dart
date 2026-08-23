import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/services/timer_service.dart';

/// A ranked "time by X" panel.
///
/// Collapsible, because the dashboard shows up to seven of these and a user
/// who only cares about projects should be able to fold the rest away. Shows
/// the top five by default with an inline control to reveal the remainder,
/// rather than silently truncating as the previous version did.
class BreakdownCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<BreakdownItem> items;
  final String emptyMessage;

  const BreakdownCard({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    this.emptyMessage = 'No tracked data for this period',
  });

  @override
  State<BreakdownCard> createState() => _BreakdownCardState();
}

class _BreakdownCardState extends State<BreakdownCard> {
  static const _collapsedCount = 5;

  bool _isCollapsed = false;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final items = widget.items;

    final total = items.fold<Duration>(
      Duration.zero,
      (sum, item) => sum + item.duration,
    );
    final visible =
        _showAll ? items : items.take(_collapsedCount).toList(growable: false);
    final hiddenCount = items.length - visible.length;

    return AppCard(
      padding: const EdgeInsets.all(Spacing.lg + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header doubles as the collapse control.
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _isCollapsed = !_isCollapsed),
              borderRadius: Radii.smAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xxs),
                child: Row(
                  children: [
                    Icon(widget.icon, size: IconSizes.md, color: colors.accent),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (total > Duration.zero) ...[
                      Text(
                        TimerService.formatDuration(total,
                            includeSeconds: false),
                        style: AppTypography.numeric(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                    ],
                    AnimatedRotation(
                      turns: _isCollapsed ? -0.25 : 0,
                      duration: Motion.duration(context, Motion.fast),
                      child: Icon(
                        Icons.expand_more,
                        size: IconSizes.md,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!_isCollapsed) ...[
            const SizedBox(height: Spacing.lg),
            if (items.isEmpty)
              EmptyState(
                icon: widget.icon,
                title: widget.emptyMessage,
                compact: true,
              )
            else ...[
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(height: Spacing.md),
                _BreakdownRow(item: visible[i]),
              ],
              if (hiddenCount > 0 || _showAll) ...[
                const SizedBox(height: Spacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.accent,
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm,
                      ),
                    ),
                    child: Text(
                      _showAll ? 'Show less' : 'Show $hiddenCount more',
                    ),
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final BreakdownItem item;

  const _BreakdownRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final color = ColorUtils.parseHex(item.colorHex);
    final fraction = (item.percentage / 100.0).clamp(0.0, 1.0);

    return Semantics(
      label: '${item.name}: '
          '${TimerService.formatDuration(item.duration, includeSeconds: false)}, '
          '${item.percentage.toStringAsFixed(1)} percent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item.iconName != null)
                Icon(
                  IconUtils.getIcon(item.iconName),
                  size: IconSizes.sm,
                  color: color,
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  item.name,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                TimerService.formatDuration(item.duration,
                    includeSeconds: false),
                style: AppTypography.numeric(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              SizedBox(
                width: 46,
                child: Text(
                  '${item.percentage.toStringAsFixed(1)}%',
                  textAlign: TextAlign.end,
                  style: AppTypography.numeric(
                    fontSize: 11,
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs + 2),
          ClipRRect(
            // Below the token scale on purpose: the bar itself is only 5px tall.
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: Motion.duration(context, Motion.slow),
              curve: Motion.curve,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                backgroundColor: colors.surfaceSunken,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
