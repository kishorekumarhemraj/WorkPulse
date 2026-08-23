# Rule: macOS Desktop UX & Quick Capture

WorkPulse is designed to feel like a high-performance native macOS utility that stays out of the user's way.

## Core UX Rules:
1. **Quick Capture Performance & Focus Isolation**:
   - The Quick Capture floating popup must render in **< 300ms** upon shortcut press.
   - Quick Capture opens as a standalone floating HUD over any focused third-party app without bringing the main WorkPulse dashboard window into focus.
   - Keep the popup lightweight, caching frequent tasks in memory for zero-lag filtering.
2. **Keyboard-First Experience**:
   - `⌥ + Space` (Option + Space) default global shortcut to trigger Quick Capture.
   - `Enter` / `Return`: Trigger primary action (Start timer, Resume task, Confirm switch).
   - `Escape`: Cancel action and hide floating window without saving incomplete drafts, immediately returning focus to the previously active app.
   - `Tab` / `Shift + Tab`: Seamlessly cycle through input fields (Task -> Project -> Category -> Tags -> People -> Configured Attributes).
   - `Arrow Up` / `Arrow Down`: Navigate task search list.
3. **macOS Menu Bar / Tray**:
   - Show live timer formatted as `⏱ HH:MM:SS  Task Name` when active in the top menu bar status item.
   - Show compact dropdown menu on click: Current task status, Stop, Switch, Open Dashboard, Settings, Quit.
4. **Window Behavior**:
   - Quick Capture window should appear centered on current active screen (`screen_retriever`).
   - Auto-hide on blur (`onWindowBlur`): clicking outside immediately dismisses the floating HUD.
   - In-app top header bar displays active timer status, project badge, live monospace duration ticker, and quick Switch / Stop buttons.
   - Prevent unnecessary full-screen windows during quick tasks.
