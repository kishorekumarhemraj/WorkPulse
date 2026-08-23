import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_theme.dart';
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
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final note = _notesController.text.trim();
    await ref.read(timerProvider.notifier).confirmSwitch(
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
    final formattedElapsed = TimerService.formatDuration(widget.currentElapsed, compact: true);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          _handleCancel();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          // If in textfield and pressing enter, submit
          _handleConfirm();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.dividerDark, width: 1),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.swap_horiz,
                color: AppTheme.accentOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Switch Active Task?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You are currently tracking another task. Switching will stop and commit your active session.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryDark, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Current Active Task card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.dividerDark),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stop_circle_outlined, size: 16, color: AppTheme.accentRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Active Task', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryDark)),
                          const SizedBox(height: 2),
                          Text(
                            widget.currentItem.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        formattedElapsed,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Arrow indicator
              const Center(
                child: Icon(Icons.arrow_downward, size: 16, color: AppTheme.textSecondaryDark),
              ),
              const SizedBox(height: 10),

              // Target Task card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_outline, size: 16, color: AppTheme.accentGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Switching To', style: TextStyle(fontSize: 11, color: AppTheme.primaryColor)),
                          const SizedBox(height: 2),
                          Text(
                            widget.targetItem.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Optional Session Note Field
              const Text(
                'Session Note (optional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryDark),
                decoration: InputDecoration(
                  hintText: 'Add closing summary or work log for previous task...',
                  hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                  filled: true,
                  fillColor: AppTheme.cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.dividerDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.dividerDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _handleCancel,
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryDark)),
          ),
          ElevatedButton(
            onPressed: _handleConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Confirm Switch'),
          ),
        ],
      ),
    );
  }
}
