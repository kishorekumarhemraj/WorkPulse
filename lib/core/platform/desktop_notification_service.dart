import 'dart:async';
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
}

class DesktopNotificationServiceImpl implements DesktopNotificationService {
  final _clickController = StreamController<String>.broadcast();
  bool _isInitialized = false;

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
}
