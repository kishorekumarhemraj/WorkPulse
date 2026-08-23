import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/constants/app_constants.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/platform/tray_service.dart';
import 'package:workpulse/core/platform/window_service.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/features/settings/providers/app_settings_provider.dart';
import 'package:workpulse/features/shell/views/main_shell_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handlers for uncaught exceptions
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[WorkPulse] Flutter error: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[WorkPulse] Uncaught error: $error\n$stack');
    return true;
  };

  // Initialize SQLite database and execute migrations
  final dbService = DatabaseService();
  await dbService.initialize();

  // Check for dangling sessions from crashes/unexpected termination
  final danglingSession = await dbService.findDanglingSession();
  if (danglingSession != null) {
    debugPrint(
        '[WorkPulse] Recovered dangling session: ${danglingSession['id']}');
  }

  // Initialize desktop window manager and system tray
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    await DesktopWindowService().initialize();
    await DesktopTrayService().initialize();
  }

  runApp(
    const ProviderScope(
      child: WorkPulseApp(),
    ),
  );
}

class WorkPulseApp extends ConsumerWidget {
  const WorkPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).valueOrNull;

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings?.themeMode ?? ThemeMode.dark,
      home: const MainShellView(),
    );
  }
}
