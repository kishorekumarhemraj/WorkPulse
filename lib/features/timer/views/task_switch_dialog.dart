import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';

class TaskSwitchDialog extends ConsumerStatefulWidget {
  final WorkItem currentItem;
  final Duration currentElapsed;
  final WorkItem targetItem;

  const TaskSwitchDialog({
    super.key,
    required this.currentItem,
    required this.currentElapsed,
    required this.targetItem,
  });

  static Future<bool?> show(
    BuildContext context, {
    required WorkItem currentItem,
    required Duration currentElapsed,
    required WorkItem targetItem,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => TaskSwitchDialog(
        currentItem: currentItem,
        currentElapsed: currentElapsed,
        targetItem: targetItem,
      ),
    );
  }

  @override
  ConsumerState<TaskSwitchDialog> createState() => _TaskSwitchDialogState();
}

class _TaskSwitchDialogState extends ConsumerState<TaskSwitchDialog> {
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    Future.microtask(() {
      if (mounted) {
        ref.read(timerProvider.notifier).requestSwitch(widget.targetItem);
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final note = _notesController.text.trim();
    await ref.read(timerProvider.notifier).confirmSwitch(
          targetItem: widget.targetItem,
          notes: note.isEmpty ? null : note,
        );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _handleCancel() {
    ref.read(timerProvider.notifier).cancelSwitch();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final formattedElapsed =
        TimerService.formatDuration(widget.currentElapsed, compact: true);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _handleCancel();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          _handleConfirm();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AppDialog(
        title: 'Switch Active Task?',
        subtitle: 'Switching stops and commits your active session.',
        icon: Icons.swap_horiz,
        iconColor: colors.warning,
        width: DialogWidth.medium,
        onSubmit: _handleConfirm,
        actions: [
          TextButton(onPressed: _handleCancel, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _handleConfirm,
            child: const Text('Confirm Switch'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Outgoing task
            _SwitchCard(
              icon: Icons.stop_circle_outlined,
              iconColor: colors.danger,
              label: 'Current Active Task',
              name: widget.currentItem.name,
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: Spacing.xxs + 1,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: Radii.smAll,
                ),
                child: Text(
                  formattedElapsed,
                  style: AppTypography.numeric(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Center(
              child: Icon(
                Icons.arrow_downward,
                size: IconSizes.md,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: Spacing.sm),

            // Incoming task
            _SwitchCard(
              icon: Icons.play_circle_outline,
              iconColor: colors.success,
              label: 'Switching To',
              labelColor: colors.accent,
              name: widget.targetItem.name,
              background: colors.accentSubtle,
              borderColor: colors.accent.withValues(alpha: Alphas.muted),
            ),
            const SizedBox(height: Spacing.lg),

            DialogField(
              label: 'Session Note (optional)',
              helperText: 'Recorded against the session you are closing.',
              child: TextField(
                controller: _notesController,
                maxLines: 2,
                style: theme.textTheme.bodyMedium,
                decoration: const InputDecoration(
                  hintText:
                      'Add a closing summary or work log for the previous task…',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One side of the before/after comparison in the switch dialog.
class _SwitchCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final String name;
  final Widget? trailing;
  final Color? background;
  final Color? borderColor;

  const _SwitchCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.name,
    this.labelColor,
    this.trailing,
    this.background,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: background ?? colors.card,
        borderRadius: Radii.mdAll,
        border: Border.all(color: borderColor ?? colors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: IconSizes.md, color: iconColor),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: labelColor ?? colors.textTertiary),
                ),
                const SizedBox(height: Spacing.xxs),
                Text(
                  name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
