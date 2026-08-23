# Rule: macOS Desktop UX & Quick Capture

WorkPulse is designed to feel like a high-performance native macOS utility that stays out of the user's way.

## Core UX Rules:
1. **Quick Capture Performance**:
   - The Quick Capture floating popup must render in **< 300ms** upon shortcut press.
   - Keep the popup lightweight, caching frequent tasks in memory for zero-lag filtering.
2. **Keyboard-First Experience**:
   - `⌥ + Space` (Option + Space) default global shortcut to trigger Quick Capture.
   - `Enter` / `Return`: Trigger primary action (Start timer, Resume task, Confirm switch).
   - `Escape`: Cancel action and hide floating window without saving incomplete drafts.
   - `Tab` / `Shift + Tab`: Seamlessly cycle through input fields (Task -> Project -> Category -> Tags -> People -> Configured Attributes).
   - `Arrow Up` / `Arrow Down`: Navigate task search list.
3. **macOS Menu Bar / Tray**:
   - Show live timer formatted as `⏱ HH:MM:SS` when active.
   - Show compact dropdown menu on click: Current task status, Stop, Switch, Open Dashboard, Settings, Quit.
4. **Window Behavior**:
   - Quick Capture window should appear centered on current active screen (`screen_retriever`).
   - Auto-hide / minimize to tray when timer starts or when dismissed.
   - Prevent unnecessary full-screen windows during quick tasks.
