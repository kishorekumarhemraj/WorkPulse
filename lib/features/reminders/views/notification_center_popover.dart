import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/core/widgets/status_badge.dart';
import 'package:workpulse/domain/models/reminder_rule.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
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
      title: 'Notification Center',
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
      child: SingleChildScrollView(
        child: remindersAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(Spacing.xl),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Text(
                'Could not load notifications: $err',
                style: TextStyle(color: colors.danger),
              ),
            ),
          ),
          data: (reminders) {
            if (reminders.isEmpty) {
              return const EmptyState(
                icon: Icons.notifications_none_outlined,
                title: 'No notifications',
                message: 'You have no delivered reminders yet.',
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
                    onComplete: workItemMap[reminders[i].workItemId] == null ||
                            workItemMap[reminders[i].workItemId]!.plan.isComplete
                        ? null
                        : () async {
                            final item = workItemMap[reminders[i].workItemId]!;
                            await ref
                                .read(workItemsProvider.notifier)
                                .completeWorkItem(item.id);
                            await ref
                                .read(remindersProvider.notifier)
                                .markRead(reminders[i].id);
                          },
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
  final WorkItem? workItem;
  final VoidCallback onMarkRead;
  final VoidCallback onSnooze;
  final VoidCallback? onComplete;
  final VoidCallback? onOpenTask;

  const _ReminderItemTile({
    required this.record,
    required this.workItem,
    required this.onMarkRead,
    required this.onSnooze,
    required this.onComplete,
    required this.onOpenTask,
  });

  String _formatRuleLabel(ReminderRule rule) => switch (rule) {
        ReminderRule.dueMorning => 'DUE TODAY',
        ReminderRule.due1h => 'DUE SOON',
        ReminderRule.overdueDaily => 'OVERDUE',
        ReminderRule.startMorning => 'STARTS TODAY',
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final timeStr = DateFormat('MMM d, HH:mm').format(record.deliveredAt.toLocal());
    final isRescheduled = workItem != null &&
        workItem!.plan.due != null &&
        workItem!.plan.due != record.anchorDate;

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
                      label: _formatRuleLabel(record.rule),
                      tone: record.isRead
                          ? BadgeTone.neutral
                          : (record.rule == ReminderRule.overdueDaily
                              ? BadgeTone.danger
                              : BadgeTone.warning),
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
                if (isRescheduled) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.update, size: 12, color: colors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        'Rescheduled to ${DateFormat('MMM d').format(workItem!.plan.due!.toLocalDateTime())}',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: Spacing.md,
                  runSpacing: Spacing.xs,
                  children: [
                    if (onOpenTask != null)
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
                    if (onComplete != null)
                      InkWell(
                        onTap: onComplete,
                        child: Text(
                          'Complete',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (!record.isRead)
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
