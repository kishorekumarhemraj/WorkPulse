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
        // Escape quotes, backslashes, and carriage returns/newlines for AppleScript
        final safeTitle = title
            .replaceAll('\\', '\\\\')
            .replaceAll('"', '\\"')
            .replaceAll('\r', ' ')
            .replaceAll('\n', ' ');
        final safeBody = body
            .replaceAll('\\', '\\\\')
            .replaceAll('"', '\\"')
            .replaceAll('\r', ' ')
            .replaceAll('\n', ' ');
        await Process.run('osascript', [
          '-e',
          'display notification "$safeBody" with title "WorkPulse" subtitle "$safeTitle"',
        ]);
      } else if (Platform.isWindows) {
        // Use PowerShell with arguments passed via stdin to avoid command-line injection
        final process = await Process.start('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'$title = [Console]::In.ReadLine(); '
              r'$body = [Console]::In.ReadLine(); '
              r'Add-Type -AssemblyName System.Windows.Forms; '
              r'$notify = New-Object System.Windows.Forms.NotifyIcon; '
              r'$notify.Icon = [System.Drawing.SystemIcons]::Information; '
              r'$notify.Visible = $True; '
              r'$notify.ShowBalloonTip(5000, $title, $body, [System.Windows.Forms.ToolTipIcon]::Info);',
        ]);
        // Normalize newlines in title and body to single line for ReadLine
        final singleLineTitle =
            title.replaceAll('\r', ' ').replaceAll('\n', ' ');
        final singleLineBody =
            body.replaceAll('\r', ' ').replaceAll('\n', ' ');
        process.stdin.writeln(singleLineTitle);
        process.stdin.writeln(singleLineBody);
        await process.stdin.flush();
        await process.stdin.close();
        await process.exitCode;
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
