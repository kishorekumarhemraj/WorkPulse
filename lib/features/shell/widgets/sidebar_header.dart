import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/constants/app_constants.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/keycap.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/features/reminders/providers/reminders_provider.dart';
import 'package:workpulse/features/reminders/views/notification_center_popover.dart';

/// Brand mark, workspace indicator, and the Quick Capture launcher.
class SidebarHeader extends StatelessWidget {
  final Workspace workspace;
  final bool isCollapsed;
  final String hotKeyLabel;
  final VoidCallback onQuickCapture;
  final VoidCallback onToggleCollapse;

  const SidebarHeader({
    super.key,
    required this.workspace,
    required this.isCollapsed,
    required this.hotKeyLabel,
    required this.onQuickCapture,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.sm,
          Spacing.lg,
          Spacing.sm,
          Spacing.md,
        ),
        child: Column(
          children: [
            Tooltip(
              message: 'Expand sidebar',
              child: IconButton(
                onPressed: onToggleCollapse,
                icon: const Icon(Icons.timer_outlined, size: IconSizes.xl),
                color: colors.accent,
                style:
                    IconButton.styleFrom(backgroundColor: colors.accentSubtle),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Tooltip(
              message: 'Quick Capture   $hotKeyLabel',
              child: IconButton(
                onPressed: onQuickCapture,
                icon: const Icon(Icons.bolt, size: IconSizes.lg),
                color: colors.accent,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            const _NotificationBellButton(),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.lg,
        Spacing.md,
        Spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.xs + 2),
                decoration: BoxDecoration(
                  color: colors.accentSubtle,
                  borderRadius: Radii.mdAll,
                ),
                child: Icon(
                  Icons.timer_outlined,
                  color: colors.accent,
                  size: IconSizes.lg,
                ),
              ),
              const SizedBox(width: Spacing.sm + 2),
              Expanded(
                child: Text(
                  AppConstants.appName,
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const _NotificationBellButton(),
              const SizedBox(width: Spacing.xs),
              Tooltip(
                message: 'Collapse sidebar',
                child: IconButton(
                  onPressed: onToggleCollapse,
                  icon: const Icon(
                    Icons.keyboard_double_arrow_left,
                    size: IconSizes.md,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),

          // Workspace indicator
          Container(
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
                Icon(
                  Icons.workspaces_outlined,
                  size: IconSizes.xs,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: Spacing.sm - 2),
                Flexible(
                  child: Text(
                    workspace.name,
                    style: theme.textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),

          // Quick Capture launcher — the app's primary entry point, so it
          // sits above the navigation rather than inside it.
          Material(
            color: colors.accentSubtle,
            borderRadius: Radii.mdAll,
            child: InkWell(
              onTap: onQuickCapture,
              borderRadius: Radii.mdAll,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: Radii.mdAll,
                  border: Border.all(
                    color: colors.accent.withValues(alpha: Alphas.muted),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md - 2,
                  vertical: Spacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.bolt, size: IconSizes.md, color: colors.accent),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        'Quick Capture',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    Keycap(hotKeyLabel),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBellButton extends ConsumerWidget {
  const _NotificationBellButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final unreadCount = ref.watch(unreadRemindersCountProvider);

    return Tooltip(
      message: unreadCount > 0
          ? 'Notifications ($unreadCount unread)'
          : 'Notifications',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: () => NotificationCenterDialog.show(context),
            icon: Icon(
              unreadCount > 0
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_outlined,
              size: IconSizes.md,
              color: unreadCount > 0 ? colors.accent : colors.textSecondary,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 26,
              minHeight: 26,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
