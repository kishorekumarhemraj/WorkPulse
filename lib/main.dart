import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/constants/app_constants.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/features/shell/views/main_shell_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In Sprint 8, desktop window manager and system tray are initialized here.
  runApp(
    const ProviderScope(
      child: WorkPulseApp(),
    ),
  );
}

class WorkPulseApp extends StatelessWidget {
  const WorkPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Default to dark for native Mac utility feel
      home: const MainShellView(),
    );
  }
}
