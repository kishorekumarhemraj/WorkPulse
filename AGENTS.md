# WorkPulse — AI Agent & Developer Guidelines

WorkPulse is a privacy-first, offline-first macOS time-tracking application built with Flutter, Riverpod, and SQLite.

## Core Architectural Invariants

1. **Offline-First & Zero Network (V1)**:
   - All data is stored locally in SQLite (`sqflite_common_ffi`).
   - Zero telemetry, analytics, or background internet calls.
   - Core tracking functionality must NEVER require network access.

2. **No Surveillance**:
   - Strictly NO screen capture, window recording, keylogging, or microphone/webcam access.
   - Idle detection only tracks user inactivity thresholds to ask the user how to classify time.

3. **Timestamp-Based Session Truth**:
   - Timers MUST calculate duration from wall-clock timestamps (`start_time`, `end_time`).
   - Never rely on continuous ticker loops as the source of truth for duration.
   - Handle Mac sleep/wake, system restart, and app crash gracefully via active session recovery.

4. **Single Active Task**:
   - Only ONE task session can be active at any given moment.
   - Switching tasks must cleanly stop the active session before starting the new session.

5. **Performance & Keyboard-First**:
   - Quick Capture popup must appear in **< 300ms**.
   - Full keyboard navigation: `Enter` to confirm, `Esc` to cancel/close, `Tab`/`Shift+Tab` to navigate, `Arrow Up`/`Arrow Down` for search list.

6. **Layered Architecture**:
   - `core/`: Foundation, theme, database provider, platform bridges, utilities.
   - `domain/`: Pure business logic, models, repository interfaces, services.
   - `data/`: SQLite implementations, DAOs, migrations, repository implementations.
   - `features/`: Feature modules containing UI, Riverpod providers, controllers, and widgets.

## Development Workflow
- Build in vertical slices following the 10 Sprints defined in the PRD.
- Write unit tests for domain logic and SQLite repositories with 100% deterministic test fixtures.
- Refer to `.agents/skills/workpulse-domain` and `.agents/skills/workpulse-sprint-guide` for detailed specs.
