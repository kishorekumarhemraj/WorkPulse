import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/features/quick_capture/views/quick_capture_body.dart';

/// Quick Capture as the whole window.
///
/// Rendered at the root of the app while [WindowMode.quickCapture] is active,
/// when `DesktopWindowService` has turned the window into a frameless,
/// always-on-top HUD floating over whatever application the user was in. That
/// is why this cannot be a dialog: a route lives inside the app's own window
/// and could not appear over another application without pulling the dashboard
/// into focus (AGENTS.md rule 3).
///
/// It has no route to pop, so [onClose] hands closing back to the window
/// service. That single difference is all that separates it from
/// [QuickCaptureDialog]; the contents come from the shared [QuickCaptureBody].
class QuickCaptureStandaloneView extends StatelessWidget {
  final VoidCallback? onClose;

  const QuickCaptureStandaloneView({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: Radii.xlAll,
          border: Border.all(color: colors.divider, width: 1.2),
        ),
        // Fills the HUD, so the configuration bar sits on the bottom edge.
        child: QuickCaptureBody(
          expandResults: true,
          onDismiss: () => onClose?.call(),
        ),
      ),
    );
  }
}
