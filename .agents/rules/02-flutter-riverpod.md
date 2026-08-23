# Rule: Flutter & Riverpod State Management

State management in WorkPulse is powered by **Riverpod 2.x**.

## Core State Principles:
1. **Single Source of Truth for Timer State**:
   - The active timer status must be managed by a dedicated `TimerNotifier` / `ActiveSessionNotifier`.
   - The state must represent one of:
     - `NoActiveTask`
     - `TaskActive(task, session, startTime)`
     - `SwitchConfirmation(currentTask, targetTask)`
     - `IdleDetected(activeSession, idleStartTime)`
2. **Immutable State**:
   - All state classes must be immutable (`@immutable` with `copyWith` or `Equatable`).
3. **Provider Rules**:
   - Use `NotifierProvider` / `AsyncNotifierProvider` for state mutation logic.
   - Use `Provider` for read-only dependencies (repositories, database instances, formatters).
   - Use `ref.watch()` inside `build()` for reactive UI bindings.
   - Use `ref.read()` only inside event callbacks (button presses, shortcut handlers).
4. **Lifecycle & Clean Disposal**:
   - Scoped state (like Quick Capture search queries, text field temporary state) should use `.autoDispose`.
   - Global long-lived state (Active Timer, Settings) should be persistent throughout app lifecycle.
