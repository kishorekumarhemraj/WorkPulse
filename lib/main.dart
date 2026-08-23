import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/constants/app_constants.dart';
import 'package:workpulse/core/theme/app_theme.dart';

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
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, size: 64, color: AppTheme.primaryColor),
              SizedBox(height: 16),
              Text(
                AppConstants.appName,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Offline-first time tracking for macOS',
                style: TextStyle(color: AppTheme.textSecondaryDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
