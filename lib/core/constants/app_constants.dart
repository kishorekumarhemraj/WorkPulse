/// Application-wide constants for WorkPulse
abstract class AppConstants {
  static const String appName = 'WorkPulse';
  static const String appVersion = '4.0.0';
  static const String dbName = 'workpulse.db';
  static const int dbVersion = 10;

  // Global Keyboard Shortcuts
  static const String defaultGlobalHotkey = 'Option + Space';

  // Performance SLA
  static const int maxPopupLatencyMs = 300;
}
