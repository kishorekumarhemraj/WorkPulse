# Rule: Platform Bridges & Native macOS Integration

WorkPulse targets macOS first while maintaining architectural readiness for Windows and Linux. Native platform interactions must adhere to strict interface isolation.

## 1. Architecture Boundaries

```text
lib/core/platform/
├── hotkey_service.dart          # Abstract HotKeyService & DesktopHotKeyService
├── tray_service.dart            # Abstract TrayService & MacOSTrayService
├── idle_detector_service.dart   # Abstract IdleDetectorService & MacOSIdleDetectorService
└── window_service.dart          # Abstract WindowService & DesktopWindowService
```

## 2. Core Constraints

1. **No Direct Plugin Singletons in UI/Domain**:
   - Widgets and Riverpod notifiers must never directly call `trayManager`, `windowManager`, `hotKeyManager`, or `screenRetriever`.
   - All platform interactions must go through abstract service contracts provided via Riverpod (`hotKeyServiceProvider`, `trayServiceProvider`, etc.).

2. **Graceful Degradation & Fallbacks**:
   - On non-desktop platforms (Web/Mobile/Tests) or unsupported operating systems, platform services must silently no-op or log debug information without crashing.
   - Guard platform code with `defaultTargetPlatform == TargetPlatform.macOS` and `!kIsWeb`.

3. **Window Management & Screen Retriever**:
   - The Quick Capture floating window should be positioned using `screen_retriever` to display on the currently focused display screen.
   - The main dashboard window must remember window size and screen bounds gracefully.

4. **Menu Bar (Tray) Invariants**:
   - When a session is active, the tray title displays `⏱ HH:MM:SS` and the work item title.
   - When idle/stopped, the tray icon displays the default WorkPulse status icon.
   - Clicking tray items dispatches intent events (`OpenQuickCapture`, `StopActiveSession`, `OpenDashboard`, `QuitApp`).
