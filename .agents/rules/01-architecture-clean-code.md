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
   - Files in `lib/domain/` MUST NEVER import Flutter UI packages (`package:flutter/material.dart`) or SQLite drivers.
   - Domain models (`WorkItem`, `Workspace`, `AttributeDefinition`, `Session`, `Project`, `Category`, etc.) must use value equality (`Equatable`) and immutable fields (`final`).
2. **Repository Pattern**:
   - `lib/domain/repositories/` defines abstract interfaces (e.g. `WorkItemRepository`, `SessionRepository`, `ProjectRepository`, `CategoryRepository`, `TagRepository`, `PersonRepository`, `AttributeRepository`, `WorkspaceRepository`).
   - `lib/data/repositories/` provides the concrete SQLite implementations.
3. **Feature Encapsulation**:
   - Each feature under `lib/features/<feature_name>/` must contain its own presentation layer:
     - `controllers/` or `providers/`: Riverpod `Notifier` / `AsyncNotifier` classes.
     - `widgets/` or `views/`: Reusable, lightweight Flutter widgets.
4. **Error Handling**:
   - Use custom `AppException` types (`DatabaseException`, `ValidationException`, `NotFoundException`) defined in `core/errors/`.
   - Never let raw database driver crashes escape to the UI layer unhandled.
