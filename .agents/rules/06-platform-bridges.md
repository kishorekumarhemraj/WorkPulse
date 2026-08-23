# Rule: Platform Bridges & Native macOS Integration

WorkPulse targets macOS first while maintaining architectural readiness for Windows and Linux. Native platform interactions must adhere to strict interface isolation.

## 1. Architecture Boundaries

```text
lib/core/platform/
├── hotkey_service.dart          # Abstract HotKeyService & DesktopHotKeyService
├── tray_service.dart            # Abstract TrayService & DesktopTrayService
├── idle_detector_service.dart   # Abstract IdleDetectorService & MacOSIdleDetectorService
└── window_service.dart          # Abstract WindowService & DesktopWindowService (WindowMode coordinator)
```

## 2. Core Constraints

1. **No Direct Plugin Singletons in UI/Domain**:
   - Widgets and Riverpod notifiers must never directly call `trayManager`, `windowManager`, `hotKeyManager`, or `screenRetriever`.
   - All platform interactions must go through abstract service contracts provided via Riverpod (`hotKeyServiceProvider`, `trayServiceProvider`, `windowServiceProvider`).

2. **Graceful Degradation & Fallbacks**:
   - On non-desktop platforms (Web/Mobile/Tests) or unsupported operating systems, platform services must silently no-op or log debug information without crashing (`NoOpWindowService`, `NoOpTrayService`, `NoOpHotKeyService`).
   - Guard platform code with `defaultTargetPlatform == TargetPlatform.macOS` and `!kIsWeb`.

3. **Window Management & Screen Retriever**:
   - `WindowService` manages two discrete window modes (`WindowMode.dashboard` and `WindowMode.quickCapture`).
   - The Quick Capture floating window is positioned using `screen_retriever` to display on the monitor containing the active mouse cursor point.
   - Quick Capture is isolated from the main application view: it does not expose or bring the dashboard into focus and auto-dismisses on blur (`onWindowBlur`).
   - The main dashboard window remembers window size and screen bounds gracefully.

4. **Menu Bar (Tray) Invariants**:
   - When a session is active, the tray title displays `⏱ HH:MM:SS  Task Name`.
   - When idle/stopped, the tray icon displays the default WorkPulse status icon and `WorkPulse` title.
   - Clicking tray items dispatches intent events (`openQuickCapture`, `stopTimer`, `openDashboard`, `quitApp`).
