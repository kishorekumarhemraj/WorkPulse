# Rule: Platform Bridges & Native macOS Integration

WorkPulse targets macOS first, with Windows as a supported platform built and tested in CI, and architectural readiness for Linux. Native platform interactions must adhere to strict interface isolation.

## 1. Architecture Boundaries

```text
lib/core/platform/
├── hotkey_service.dart          # Abstract HotKeyService & DesktopHotKeyService
├── tray_service.dart            # Abstract TrayService & DesktopTrayService
├── idle_detector_service.dart   # Abstract IdleDetectorService & DesktopIdleDetectorService
├── system_idle_source.dart      # OS "seconds since last input" via dart:ffi (see docs/adr/001)
└── window_service.dart          # Abstract WindowService & DesktopWindowService (WindowMode coordinator)
```

## 2. Core Constraints

1. **No Direct Plugin Singletons in UI/Domain**:
   - Widgets and Riverpod notifiers must never directly call `trayManager`, `windowManager`, `hotKeyManager`, or `screenRetriever`.
   - All platform interactions must go through abstract service contracts provided via Riverpod (`hotKeyServiceProvider`, `trayServiceProvider`, `windowServiceProvider`).

2. **Graceful Degradation & Fallbacks**:
   - On non-desktop platforms (Web/Mobile/Tests) or unsupported operating systems, platform services must silently no-op or log debug information without crashing (`NoOpWindowService`, `NoOpTrayService`, `NoOpHotKeyService`).
   - Guard platform code with a platform check and `!kIsWeb`. Where a platform simply cannot answer (system idle time on Linux), report "unknown" and let the caller stay quiet — never substitute a guess.
   - Never write a keyboard shortcut hint with a literal `⌘`/`⌥`. Use `ShortcutLabels` (`lib/core/keyboard/`), and register both the `meta:` and `control:` activator for every in-app shortcut.

3. **Window Management & Screen Retriever**:
   - `WindowService` manages two discrete window modes (`WindowMode.dashboard` and `WindowMode.quickCapture`).
   - The Quick Capture floating window is positioned using `screen_retriever` to display on the monitor containing the active mouse cursor point.
   - Quick Capture is isolated from the main application view: it does not expose or bring the dashboard into focus and auto-dismisses on blur (`onWindowBlur`).
   - The main dashboard window remembers window size and screen bounds gracefully.

4. **Menu Bar (Tray) Invariants**:
   - When a session is active, the tray title displays `⏱ HH:MM:SS  Task Name`.
   - When idle/stopped, the tray icon displays the default WorkPulse status icon and `WorkPulse` title.
   - Clicking tray items dispatches intent events (`openQuickCapture`, `stopTimer`, `openDashboard`, `quitApp`).
