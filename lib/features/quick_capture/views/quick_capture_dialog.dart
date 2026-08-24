import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/features/quick_capture/views/quick_capture_body.dart';

/// Quick Capture as an in-app dialog, opened from the active timer bar.
///
/// The floating window variant is [QuickCaptureStandaloneView]; both render the
/// same [QuickCaptureBody] and differ only in chrome and in how they close.
class QuickCaptureDialog extends StatelessWidget {
  const QuickCaptureDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: true,
      builder: (context) => const QuickCaptureDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 620,
          constraints: const BoxConstraints(maxHeight: 640, minHeight: 400),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.xlAll,
            border: Border.all(color: colors.divider, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 12),
                blurRadius: 36,
                spreadRadius: 4,
              ),
            ],
          ),
          // Shrink-wraps its content, so the result list stays loose.
          child: QuickCaptureBody(
            onDismiss: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
