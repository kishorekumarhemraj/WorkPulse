import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/constants/app_constants.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/platform/tray_service.dart';
import 'package:workpulse/core/platform/window_service.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/features/quick_capture/views/quick_capture_standalone_view.dart';
import 'package:workpulse/features/settings/providers/app_settings_provider.dart';
import 'package:workpulse/features/shell/views/main_shell_view.dart';
import 'package:workpulse/features/tray/providers/tray_provider.dart';

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

  try {
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
    if (!kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      await DesktopWindowService().initialize();
      await DesktopTrayService().initialize();
    }

    runApp(
      const ProviderScope(
        child: WorkPulseApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint('[WorkPulse] Fatal initialization error: $e\n$stack');
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          backgroundColor: AppTheme.backgroundDark,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: AppTheme.accentRed, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'WorkPulse failed to start',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.textSecondaryDark, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorkPulseApp extends ConsumerStatefulWidget {
  final WindowService? windowService;

  const WorkPulseApp({
    super.key,
    this.windowService,
  });

  @override
  ConsumerState<WorkPulseApp> createState() => _WorkPulseAppState();
}

class _WorkPulseAppState extends ConsumerState<WorkPulseApp> {
  late final WindowService _windowService;

  @override
  void initState() {
    super.initState();
    _windowService = widget.windowService ?? ref.read(windowServiceProvider);
    // The tray owns its own menu actions; the app only has to bring it up.
    // This is the one place it is initialized — MainShellView used to do it a
    // second time, registering a callback that opened Quick Capture twice.
    Future.microtask(() => ref.read(trayCoordinatorProvider).initialize());
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider).value;

    return ValueListenableBuilder<WindowMode>(
      valueListenable: _windowService.windowModeNotifier,
      builder: (context, mode, _) {
        final isQuickCapture = mode == WindowMode.quickCapture;

        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings?.themeMode ?? ThemeMode.dark,
          color: isQuickCapture ? Colors.transparent : null,
          home: isQuickCapture
              ? ScaffoldMessenger(
                  child: QuickCaptureStandaloneView(
                    onClose: () => _windowService.closeQuickCapture(),
                  ),
                )
              : const MainShellView(),
        );
      },
    );
  }
}
