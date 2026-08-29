import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';

/// A yes/no confirmation, used before anything destructive.
///
/// Each screen previously built its own AlertDialog for this, so the wording,
/// button styling and even whether the consequence was explained varied
/// screen to screen.
///
/// Keyboard: the confirm button takes initial focus, so `Enter` confirms and
/// `Escape` (handled by the modal route) cancels. Before that, focus landed on
/// the header's close button and `Enter` did nothing at all until the user had
/// tabbed twice.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  IconData icon = Icons.delete_outline,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final colors = ctx.colors;
      return AppDialog(
        title: title,
        icon: icon,
        iconColor: colors.danger,
        width: DialogWidth.small,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.dangerFill,
              foregroundColor: colors.onAccent,
            ),
            child: Text(confirmLabel),
          ),
        ],
        child: Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
      );
    },
  );
  return result ?? false;
}
