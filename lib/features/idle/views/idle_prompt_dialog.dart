import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/widgets/keycap.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/idle/providers/idle_provider.dart';

class IdlePromptDialog extends ConsumerStatefulWidget {
  final Duration idleDuration;
  final DateTime idleStartTime;
  final WorkItem activeWorkItem;

  const IdlePromptDialog({
    super.key,
    required this.idleDuration,
    required this.idleStartTime,
    required this.activeWorkItem,
  });

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final idleState = ref.watch(idleNotifierProvider);
          if (!idleState.isPromptVisible ||
              idleState.currentEvent == null ||
              idleState.activeWorkItem == null) {
            return const SizedBox.shrink();
          }

          return IdlePromptDialog(
            idleDuration: idleState.currentEvent!.idleDuration,
            idleStartTime: idleState.currentEvent!.idleStartTime,
            activeWorkItem: idleState.activeWorkItem!,
          );
        },
      ),
    );
  }

  @override
  ConsumerState<IdlePromptDialog> createState() => _IdlePromptDialogState();
}

class _IdlePromptDialogState extends ConsumerState<IdlePromptDialog> {
  bool _isProcessing = false;

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Future<void> _handleKeepTracking() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await ref.read(idleNotifierProvider.notifier).keepTracking();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleMarkIdle() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await ref.read(idleNotifierProvider.notifier).markIdle();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleStopSession() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await ref.read(idleNotifierProvider.notifier).stopSession();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final timeStr = DateFormat.jm().format(widget.idleStartTime.toLocal());
    final durationStr = _formatDuration(widget.idleDuration);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            _handleKeepTracking();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
            _handleMarkIdle();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyS ||
              event.logicalKey == LogicalKeyboardKey.escape) {
            _handleStopSession();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AppDialog(
        title: 'Inactivity Detected',
        subtitle: 'You were away while the timer was running.',
        icon: Icons.nightlight_round,
        iconColor: colors.warning,
        width: DialogWidth.medium,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // How long they were away — the number that drives the decision.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: colors.warningSubtle,
                borderRadius: Radii.lgAll,
                border: Border.all(
                  color: colors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    durationStr,
                    style: AppTypography.numeric(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: colors.warning,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Idle period started at $timeStr',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md + 2),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md + 2,
                vertical: Spacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: Radii.mdAll,
                border: Border.all(color: colors.divider),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: IconSizes.md,
                    color: colors.success,
                  ),
                  const SizedBox(width: Spacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Task',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: colors.textTertiary),
                        ),
                        Text(
                          widget.activeWorkItem.name,
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),

            Text(
              'How would you like to handle this time?',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: Spacing.sm + 2),

            _buildOptionTile(
              title: 'Keep Tracking',
              subtitle: 'Count this entire time as active work',
              shortcut: '↩',
              icon: Icons.play_arrow_outlined,
              color: colors.accent,
              onTap: _handleKeepTracking,
            ),
            const SizedBox(height: Spacing.sm),
            _buildOptionTile(
              title: 'Mark as Idle & Resume',
              subtitle: 'Discard the idle time and restart the timer from now',
              shortcut: 'M',
              icon: Icons.replay,
              color: colors.info,
              onTap: _handleMarkIdle,
            ),
            const SizedBox(height: Spacing.sm),
            _buildOptionTile(
              title: 'Stop Timer at Inactivity',
              subtitle: 'End tracking at $timeStr, when the inactivity began',
              shortcut: 'S',
              icon: Icons.stop_circle_outlined,
              color: colors.danger,
              onTap: _handleStopSession,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required String shortcut,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: colors.card,
        borderRadius: Radii.mdAll,
        child: InkWell(
          onTap: _isProcessing ? null : onTap,
          borderRadius: Radii.mdAll,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: Radii.mdAll,
              border: Border.all(color: colors.divider),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm + 2,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Spacing.xs + 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: Radii.smAll,
                  ),
                  child: Icon(icon, color: color, size: IconSizes.lg),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Keycap(shortcut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
