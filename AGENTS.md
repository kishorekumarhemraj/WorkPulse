# WorkPulse — AI Agent & Developer Guidelines

WorkPulse is a privacy-first, offline-first desktop time-tracking and work-awareness application built with Flutter, Riverpod, and SQLite. macOS is the primary target; Windows is a supported platform, built and tested in CI.

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

7. **A Session Is Not Its WorkItem**:
   - Stopping a session simply closes the time tracking block. The WorkItem remains available to resume later.
   - A WorkItem's `categoryId`, `tagIds` and `peopleIds` seed its **first** session only. Every session after that starts unclassified and is the user's to set — the second hour on a task is often not the same kind of work as the first.
   - Nothing borrows the WorkItem's classification at **read time**. Analytics, exports and the session editor show exactly what each session says; unclassified time is bucketed as `Uncategorized` rather than dropped or silently attributed upward.
   - The one exception is an idle split: the resumed half is a continuation, so it carries the interrupted half's own classification forward.
   - Anything a caller passes to `TimerService.startSession` explicitly always wins, on any session.

8. **Offline-First & Zero Network (V1)**:
   - All data is stored locally in SQLite (`sqflite_common_ffi`).
   - Zero telemetry, analytics, or background outbound network calls in V1.

9. **Platform-Specific Code Must Be Isolated**:
   - Native integrations (tray, global shortcut `⌥ + Space` / `Alt + Space`, idle detection, window management, opening and revealing exported files) live behind clean platform service interfaces in `lib/core/platform/`.
   - Every interface has a fallback for platforms lacking the capability. Where a platform cannot answer at all — system idle time on Linux — report "unknown" and stay quiet rather than guessing.
   - Keyboard shortcuts bind both the `meta:` and `control:` activator, and are *labelled* through `ShortcutLabels` so hints read correctly on each platform. Never hardcode `⌘` or `⌥` in UI text.

10. **Migration-Based Database with Stable UUIDs**:
    - All entity IDs are stable UUIDs.
    - All schema evolution is strictly versioned via migration scripts with `PRAGMA user_version`.

## Layered Architecture
- `lib/core/`: Foundation, theme, database provider, platform bridges, error types, utilities.
- `lib/domain/`: Pure Dart business logic, models (`WorkItem`, `Workspace`, `Session`, `Project`, `Category`, `Tag`, `Person`, `AttributeDefinition`, `AttributeOption`, `IdlePeriod`), repository interfaces, services (NO Flutter/SQLite dependencies).
- `lib/data/`: SQLite tables, migrations, DAOs, concrete repository implementations.
- `lib/features/`: Feature modules containing UI, Riverpod providers, controllers, and widgets.

## Specialized Rules Reference
- [01-architecture-clean-code.md](file:///Users/kkh/Code/WorkPulse/.agents/rules/01-architecture-clean-code.md)
- [02-flutter-riverpod.md](file:///Users/kkh/Code/WorkPulse/.agents/rules/02-flutter-riverpod.md)
- [03-offline-data-sqlite.md](file:///Users/kkh/Code/WorkPulse/.agents/rules/03-offline-data-sqlite.md)
- [04-macos-desktop-ux.md](file:///Users/kkh/Code/WorkPulse/.agents/rules/04-macos-desktop-ux.md)
- [05-testing-and-mocking.md](file:///Users/kkh/Code/WorkPulse/.agents/rules/05-testing-and-mocking.md)
- [06-platform-bridges.md](file:///Users/kkh/Code/WorkPulse/.agents/rules/06-platform-bridges.md)

## Development Workflow & Skills
- Build in vertical slices following the 10 Sprints defined in [workpulse-sprint-guide](file:///Users/kkh/Code/WorkPulse/.agents/skills/workpulse-sprint-guide/SKILL.md).
- Refer to [workpulse-domain](file:///Users/kkh/Code/WorkPulse/.agents/skills/workpulse-domain/SKILL.md) for domain models and state machines.
- Consult [DESIGN.md](file:///Users/kkh/Code/WorkPulse/docs/DESIGN.md) for technical design and [DEVELOPMENT.md](file:///Users/kkh/Code/WorkPulse/docs/DEVELOPMENT.md) for local dev commands.

## Git Commit & Attribution Guidelines
All Git commits created with AI agents should include standard GitHub co-author attribution trailers in the commit message body:
- **Antigravity / Gemini**:
  ```text
  Co-Authored-By: Antigravity <antigravity@users.noreply.github.com>
  ```
- **Claude**:
  ```text
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

