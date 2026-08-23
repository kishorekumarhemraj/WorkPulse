# Rule: Clean Layered Architecture

WorkPulse follows a strict 4-layer architecture to keep the business logic testable, platform-agnostic, and decoupled from UI or database drivers:

```text
lib/
├── core/       # Shared utilities, theme, error types, database manager, platform adapters
├── domain/     # Pure Dart models, repository interfaces, business rules (NO Flutter/SQLite imports)
├── data/       # SQLite database implementation, tables, migrations, concrete repositories
└── features/   # Feature-based UI, Riverpod state notifiers, presentation widgets
```

## Rules & Constraints:

1. **Domain Independence**:
   - Files in `lib/domain/` MUST NEVER import Flutter UI packages (`package:flutter/material.dart`), UI frameworks, or SQLite drivers.
   - Domain models (`WorkItem`, `Workspace`, `AttributeDefinition`, `Session`, `Project`, `Category`, `Tag`, `Person`, `IdlePeriod`, etc.) must use value equality (`Equatable`) and immutable fields (`final`).
   - The domain layer always uses the term **`WorkItem`**. User-facing UI may display "Task" for natural readability.

2. **Repository Pattern**:
   - `lib/domain/repositories/` defines abstract interfaces (e.g. `WorkItemRepository`, `SessionRepository`, `ProjectRepository`, `CategoryRepository`, `TagRepository`, `PersonRepository`, `AttributeRepository`, `WorkspaceRepository`, `SettingsRepository`).
   - `lib/data/repositories/` provides the concrete SQLite implementations.
   - Presentation layers depend exclusively on abstract repository interfaces injected via Riverpod providers (`lib/data/providers/repository_providers.dart`).

3. **Platform Isolation**:
   - Native macOS integrations (`tray_manager`, `hotkey_manager`, `window_manager`, `screen_retriever`) must be isolated behind abstract service contracts in `lib/core/platform/`.
   - Feature controllers and widgets must never invoke native platform channel singletons directly.

4. **Feature Encapsulation**:
   - Each feature under `lib/features/<feature_name>/` contains its presentation logic:
     - `models/`: Feature-specific presentation view states (e.g., `QuickCaptureState`, `TimerState`).
     - `providers/`: Riverpod `Notifier` / `AsyncNotifier` classes.
     - `widgets/` or `views/`: Reusable, lightweight Flutter widgets.

5. **Error Handling**:
   - Use custom `AppException` types (`DatabaseException`, `ValidationException`, `NotFoundException`) defined in `core/errors/`.
   - Never let raw database driver crashes escape to the UI layer unhandled.
