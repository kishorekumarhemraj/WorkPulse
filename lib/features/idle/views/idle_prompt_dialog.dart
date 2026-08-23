import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_theme.dart';
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
          if (!idleState.isPromptVisible || idleState.currentEvent == null || idleState.activeWorkItem == null) {
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
          } else if (event.logicalKey == LogicalKeyboardKey.keyS || event.logicalKey == LogicalKeyboardKey.escape) {
            _handleStopSession();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.dividerDark, width: 1),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.nightlight_round, color: AppTheme.accentOrange, size: 24),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inactivity Detected',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
                ),
                SizedBox(height: 2),
                Text(
                  'You were away while timer was running',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                ),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Idle Duration Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.dividerDark),
                ),
                child: Column(
                  children: [
                    Text(
                      durationStr,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentOrange,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Idle period started at $timeStr',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Active Task Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.dividerDark.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: AppTheme.accentGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active Task', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryDark)),
                          Text(
                            widget.activeWorkItem.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'How would you like to handle this time?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryDark),
              ),
              const SizedBox(height: 10),

              // Action Options list
              _buildOptionTile(
                title: 'Keep Tracking',
                subtitle: 'Count this entire time as active work (Enter)',
                shortcut: 'Enter',
                icon: Icons.play_arrow_outlined,
                color: AppTheme.primaryColor,
                onTap: _handleKeepTracking,
              ),
              const SizedBox(height: 8),
              _buildOptionTile(
                title: 'Mark as Idle & Resume',
                subtitle: 'Discard idle time and restart timer from now (M)',
                shortcut: 'M',
                icon: Icons.replay,
                color: AppTheme.accentPurple,
                onTap: _handleMarkIdle,
              ),
              const SizedBox(height: 8),
              _buildOptionTile(
                title: 'Stop Timer at Inactivity',
                subtitle: 'End tracking at $timeStr when inactivity began (S / Esc)',
                shortcut: 'S',
                icon: Icons.stop_circle_outlined,
                color: AppTheme.accentRed,
                onTap: _handleStopSession,
              ),
            ],
          ),
        ),
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
    return InkWell(
      onTap: _isProcessing ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.dividerDark),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryDark),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.dividerDark),
              ),
              child: Text(
                shortcut,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
