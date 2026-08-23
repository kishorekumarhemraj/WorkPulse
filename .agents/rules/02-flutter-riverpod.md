# Rule: Flutter & Riverpod State Management

State management in WorkPulse is powered by **Riverpod 3.x** (`flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`).

## Core State Principles:
1. **Single Source of Truth for Timer State**:
   - The active timer status must be managed by a dedicated `TimerNotifier` / `ActiveSessionNotifier`.
   - The state must deterministically represent one of:
     - `NoActiveSession` (Timer idle, no session running)
     - `StartingSession` (Transitioning / initializing session)
     - `SessionActive(workItem, session, elapsed)` (Active tracking with wall-clock elapsed duration)
     - `SwitchConfirmation(currentWorkItem, targetWorkItem)` (Switching prompt pending user decision)
     - `StoppingSession` (Committing and closing session)
     - `IdleDetected(session, idleStartTime)` (Inactivity detected, awaiting user resolution)
2. **Immutable State**:
   - All state classes must be immutable (`@immutable` with `copyWith` and `Equatable`).
3. **Provider Rules**:
   - Use `NotifierProvider` / `AsyncNotifierProvider` (or `@riverpod` annotations) for state mutation logic.
   - Use `Provider` for read-only dependencies (repositories, database instances, formatters, platform services).
   - Use `ref.watch()` inside `build()` methods for reactive UI bindings.
   - Use `ref.read()` only inside event callbacks (button clicks, keyboard shortcut triggers).
4. **Lifecycle & Clean Disposal**:
   - Scoped state (like Quick Capture search queries, modal form drafts) should use `.autoDispose`.
   - Global long-lived state (Active Timer, Settings, Workspace context) should remain alive throughout the application lifecycle.
5. **Separation of Presentation & Business Logic**:
   - UI widgets must never directly execute database queries or mutate raw models.
   - All actions must be dispatched through domain services or Riverpod notifiers.
