import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/quick_capture/views/quick_capture_dialog.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';

class ActiveTimerBar extends ConsumerWidget {
  const ActiveTimerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider).value;
    final projects = ref.watch(projectsProvider).value ?? [];
    final workItems = ref.watch(workItemsProvider).value ?? [];

    if (timerState == null || !timerState.isRunning || timerState.activeWorkItem == null) {
      return const SizedBox.shrink();
    }

    final activeItem = workItems.where((w) => w.id == timerState.activeWorkItem!.id).firstOrNull ?? timerState.activeWorkItem!;
    final project = projects.where((p) => p.id == activeItem.projectId).firstOrNull;
    final projectColor = ColorUtils.parseHex(project?.colorHex);
    final formattedTime = TimerService.formatDuration(timerState.elapsed, includeSeconds: true);

    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.getColors(context).surface,
        border: Border(
          top: BorderSide(color: AppTheme.getColors(context).divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            offset: const Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          // Pulsing status dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppTheme.accentGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentGreen.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: 12),

          // Active label
          Text(
            'TRACKING',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppTheme.accentGreen,
            ),
          ),
          SizedBox(width: 12),

          // Project indicator
          if (project != null) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: projectColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: projectColor, shape: BoxShape.circle),
                  ),
                  SizedBox(width: 4),
                  Text(
                    project.name,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: projectColor),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
          ],

          // Active task title
          Expanded(
            child: Text(
              activeItem.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.getColors(context).textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Live Duration Ticker
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.getColors(context).card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.getColors(context).divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 14, color: AppTheme.primaryColor),
                SizedBox(width: 6),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getColors(context).textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),

          // Switch Task Button
          OutlinedButton.icon(
            onPressed: () => QuickCaptureDialog.show(context),
            icon: Icon(Icons.swap_horiz, size: 15),
            label: Text('Switch'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.getColors(context).textPrimary,
              side: BorderSide(color: AppTheme.getColors(context).divider),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          SizedBox(width: 8),

          // Stop Button
          ElevatedButton.icon(
            onPressed: () => ref.read(timerProvider.notifier).stopTimer(),
            icon: Icon(Icons.stop, size: 16),
            label: Text('Stop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed.withValues(alpha: 0.15),
              foregroundColor: AppTheme.accentRed,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(color: AppTheme.accentRed, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
