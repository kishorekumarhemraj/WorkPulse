import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/core/widgets/status_badge.dart';
import 'package:workpulse/domain/models/work_item_reminder_record.dart';
import 'package:workpulse/features/reminders/providers/reminders_provider.dart';
import 'package:workpulse/features/settings/views/reminder_settings_dialog.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/tasks/views/task_form_dialog.dart';

class NotificationCenterDialog extends ConsumerWidget {
  const NotificationCenterDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: context.colors.overlay,
      builder: (_) => const NotificationCenterDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final remindersAsync = ref.watch(remindersProvider);
    final workItems = ref.watch(workItemsProvider).value ?? [];
    final workItemMap = {for (final item in workItems) item.id: item};

    return AppDialog(
      title: 'Notifications',
      subtitle: 'Delivered reminders and schedule updates',
      icon: Icons.notifications_outlined,
      width: DialogWidth.medium,
      leadingFooter: IconButton(
        tooltip: 'Reminder Settings',
        icon: const Icon(Icons.settings_outlined, size: IconSizes.md),
        onPressed: () {
          Navigator.of(context).pop();
          ReminderSettingsDialog.show(context);
        },
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await ref.read(remindersProvider.notifier).markAllRead();
          },
          child: const Text('Mark all as read'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: remindersAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(Spacing.xl),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Center(
            child: Text('Could not load notifications: $err'),
          ),
          data: (reminders) {
            if (reminders.isEmpty) {
              return const EmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'No notifications',
                message:
                    'When upcoming or overdue reminders trigger, they will appear here.',
                compact: true,
              );
            }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < reminders.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.divider),
                _ReminderItemTile(
                  record: reminders[i],
                  workItem: workItemMap[reminders[i].workItemId],
                  onMarkRead: () =>
                      ref.read(remindersProvider.notifier).markRead(reminders[i].id),
                  onSnooze: () => ref
                      .read(remindersProvider.notifier)
                      .snooze(reminders[i].id, const Duration(hours: 1)),
                  onOpenTask: workItemMap[reminders[i].workItemId] == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          TaskFormDialog.show(
                            context,
                            workItem: workItemMap[reminders[i].workItemId]!,
                          );
                        },
                ),
              ],
            ],
          );
          },
        ),
      ),
    );
  }
}

class _ReminderItemTile extends StatelessWidget {
  final WorkItemReminderRecord record;
  final dynamic workItem;
  final VoidCallback onMarkRead;
  final VoidCallback onSnooze;
  final VoidCallback? onOpenTask;

  const _ReminderItemTile({
    required this.record,
    required this.workItem,
    required this.onMarkRead,
    required this.onSnooze,
    required this.onOpenTask,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final timeStr = DateFormat('MMM d, HH:mm').format(record.deliveredAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Spacing.sm,
        horizontal: Spacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: Spacing.sm),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: record.isRead ? Colors.transparent : colors.accent,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusBadge(
                      label: record.rule.name.toUpperCase(),
                      tone: record.isRead ? BadgeTone.neutral : BadgeTone.warning,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        workItem?.name ?? 'Work Item',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              record.isRead ? FontWeight.normal : FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  record.rule.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (onOpenTask != null) ...[
                      InkWell(
                        onTap: onOpenTask,
                        child: Text(
                          'View task',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                    ],
                    if (!record.isRead) ...[
                      InkWell(
                        onTap: onMarkRead,
                        child: Text(
                          'Mark read',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                    ],
                    InkWell(
                      onTap: onSnooze,
                      child: Text(
                        'Snooze 1h',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
