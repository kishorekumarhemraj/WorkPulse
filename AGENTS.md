# WorkPulse — AI Agent & Developer Guidelines

WorkPulse is a privacy-first, offline-first macOS time-tracking and work-awareness application built with Flutter, Riverpod, and SQLite.

## 10 Critical Architectural Rules

1. **Jira Must Not Appear Anywhere in Core Domain Model**:
   - Zero hardcoded external tool fields (Jira, Azure DevOps, ServiceNow, etc.) in the core domain or database schema.
   - All organisation-specific and workflow-specific metadata must use the configurable attribute system.

2. **Organisation-Specific Metadata Must Be Configurable**:
   - Supported via `AttributeDefinition`, `AttributeOption`, `WorkItemAttributeValue`, and `SessionAttributeValue`.
   - Supports 6 typed categories (`text`, `number`, `boolean`, `single_select`, `multi_select`, `date`) and 2 scopes (`TASK`, `SESSION`).

3. **Quick Capture Must Remain Fast (<300ms)**:
   - Primary interaction is a floating keyboard-first window appearing in <300ms perceived response time.
   - Full keyboard navigation: `Enter` to confirm, `Esc` to cancel/close, `Tab`/`Shift+Tab` to cycle fields, `Arrow Up`/`Arrow Down` to navigate search results.

4. **One and Only One Active Session**:
   - Exactly ONE work session can be active at any given moment.
   - Switching work items cleanly stops and commits the active session before starting a new session.

5. **Timestamp-Based Session Truth**:
   - Timers MUST calculate duration from wall-clock timestamps (`start_time`, `end_time`).
   - Never rely on continuous ticker loops as the source of truth for duration.
   - System restart, Mac sleep/wake, and app crashes recover active session seamlessly from SQLite.

6. **Historical Data Must Never Be Silently Destroyed**:
   - Disabling/deleting an attribute or option archives it (`archived_at`), preserving historical work item values.
   - Idle periods and stopped sessions are never silently discarded.

7. **Stopping a Session Does Not Complete the WorkItem**:
   - Stopping a session simply closes the time tracking block. The WorkItem remains available to resume later.

8. **Offline-First & Zero Network (V1)**:
   - All data is stored locally in SQLite (`sqflite_common_ffi`).
   - Zero telemetry, analytics, or background outbound network calls in V1.

9. **Platform-Specific Code Must Be Isolated**:
   - Native macOS integrations (menu bar tray, global shortcut `⌥ + Space`, idle detection, notifications) live behind clean platform service interfaces.

10. **Migration-Based Database with Stable UUIDs**:
    - All entity IDs are stable UUIDs.
    - All schema evolution is strictly versioned via migration scripts with `PRAGMA user_version`.

## Layered Architecture
- `lib/core/`: Foundation, theme, database provider, platform bridges, error types, utilities.
- `lib/domain/`: Pure Dart business logic, models (`WorkItem`, `Workspace`, `Session`, `Project`, `Category`, `Tag`, `Person`, `AttributeDefinition`, `AttributeOption`, `IdlePeriod`), repository interfaces, services (NO Flutter/SQLite dependencies).
- `lib/data/`: SQLite tables, migrations, DAOs, concrete repository implementations.
- `lib/features/`: Feature modules containing UI, Riverpod providers, controllers, and widgets.

## Development Workflow
- Build in vertical slices following the 10 Sprints defined in the PRD.
- Write unit tests for domain logic and SQLite repositories with 100% deterministic test fixtures.
- Refer to `.agents/skills/workpulse-domain` and `.agents/skills/workpulse-sprint-guide` for detailed specs.
