import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

abstract class DesktopNotificationService {
  Future<void> initialize();
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  });
  Stream<String> get onNotificationClicked;
  void dispose();
}

class DesktopNotificationServiceImpl implements DesktopNotificationService {
  final _clickController = StreamController<String>.broadcast();
  bool _isInitialized = false;

  @override
  void dispose() {
    _clickController.close();
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint('[WorkPulse Notification] $title: $body');

    try {
      if (Platform.isMacOS) {
        // Escape quotes and backslashes for AppleScript
        final safeTitle = title.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
        final safeBody = body.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
        await Process.run('osascript', [
          '-e',
          'display notification "$safeBody" with title "WorkPulse" subtitle "$safeTitle"',
        ]);
      } else if (Platform.isWindows) {
        // Fallback or PowerShell notification
        final safeTitle = title.replaceAll('"', '`"');
        final safeBody = body.replaceAll('"', '`"');
        await Process.run('powershell', [
          '-Command',
          'Add-Type -AssemblyName System.Windows.Forms; '
              '\$notify = New-Object System.Windows.Forms.NotifyIcon; '
              '\$notify.Icon = [System.Drawing.SystemIcons]::Information; '
              '\$notify.Visible = \$True; '
              '\$notify.ShowBalloonTip(5000, "$safeTitle", "$safeBody", [System.Windows.Forms.ToolTipIcon]::Info);',
        ]);
      }
    } catch (e) {
      debugPrint('[WorkPulse Notification] Failed to display native notification: $e');
    }
  }

  @override
  Stream<String> get onNotificationClicked => _clickController.stream;
}

class NoOpDesktopNotificationService implements DesktopNotificationService {
  final List<Map<String, dynamic>> shownNotifications = [];
  final _clickController = StreamController<String>.broadcast();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shownNotifications.add({
      'id': id,
      'title': title,
      'body': body,
      'payload': payload,
    });
  }

  void simulateClick(String payload) {
    _clickController.add(payload);
  }

  @override
  Stream<String> get onNotificationClicked => _clickController.stream;

  @override
  void dispose() {
    _clickController.close();
  }
}
