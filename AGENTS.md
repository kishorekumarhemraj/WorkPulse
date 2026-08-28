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
   - A WorkItem's `tagIds` and `peopleIds` seed its **first** session only. Every session after that starts with none, and they are the user's to set — who was in an hour and what that hour was about genuinely vary session to session.
   - **`categoryId` is inherited from the task's previous session**, falling back to the WorkItem's own category when there is no previous session. A category names the *kind* of work, which is usually stable across a task's life, and an unclassified session stays unclassified because nobody revisits it — a wrong inherited category is visible and one click to fix, a blank one is invisible. This is inheritance at **write** time and is copied onto the row, unlike the financial classification below, which is resolved at read time.
   - Nothing borrows the WorkItem's classification at **read time**. Analytics, exports and the session editor show exactly what each session says; unclassified time is bucketed as `Uncategorized` rather than dropped or silently attributed upward.
   - The one exception is an idle split: the resumed half is a continuation, so it carries the interrupted half's own classification forward.
   - **Financial classification is the single deliberate exception to the read-time rule.** `Session.financialClassification` is nullable and null means "inherit from the WorkItem", resolved on read. What an hour was *for* belongs to the task and stays true across its life; what *kind* of work it took does not, which is why category, tags and people still never borrow upward. See the Financial Classification section below.
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

## Financial Classification (CapEx / OpEx)

- `FinancialClassification` (`CAPEX` / `OPEX` / `NONE`) is a first-class field on **`WorkItem`**, not on `Category` and not a configurable attribute. It answers "what was this hour *for*", which is a property of the task; a category answers "what shape did the work take", and the same shape can be either — a design meeting about a new feature is capital, the same meeting about last week's outage is not. An earlier cut put it on the category and could not express that.
- **Sessions inherit it at read time.** `Session.financialClassification` is nullable and null means *inherit*; the resolution happens in `Session.classificationWithin` and nowhere else. This is a deliberate, single exception to rule 7: correcting a misclassified task must correct the hours it already booked, because those hours were always that task's purpose — whereas the *kind* of work genuinely varies session to session, so category, tags and people still follow rule 7 exactly.
- `SessionExportRecord.classification` is where inheritance is resolved for every consumer. Reports, exports and the Time Sheet read it; none of them re-derive the fallback, or they would drift.
- `NONE` is an honest state, never a default dressed as a decision. New tasks start there and unreadable values fall back there. Defaulting to `OPEX` would invent a finance decision nobody made, so the CapEx ratio is taken over *classified* time and unclassified hours are reported in their own bucket.
- `MigrationV5` was **rewritten in place** rather than superseded, so the schema carries no vestige of the category-level shape. It is fully guarded and re-runnable, and `DatabaseService` replays it on the way to v7 so development databases stamped at 5 or 6 still reach the new shape. Any future change to this area needs a new migration, not another rewrite.
- The project table, the task table, the per-classification category tables and every attribute table are views of the same hours and must always sum to the same total. That is why a multi-select value stays whole ("Backend; Platform" is one row) rather than being counted once per option.
- `Project.timesheetCode` is the code the organisation books a project against. Optional in the project form, allowing multiple projects to share the same code or none at all, and **nullable in the schema**: unlike the classification there is no conservative default, because a cost code is an external identifier the app cannot invent and a made-up one would be booked against real hours. `MigrationV6` adds the column without backfilling, and the Time Sheet reports a missing code as **No code**.

## Pattern Insights
- Every finding lands in exactly one of four lanes — `sustain` (Continue), `reclaim`, `delegate`, `plan` — and carries the figures it was derived from. A finding with no evidence is a bug.
- `sustain` is first in `InsightAction` on purpose: a page that only ever lists faults stops being opened, and an unnoticed habit is the easiest one to lose. (`sustain`, not `continue`, because `continue` is a Dart keyword.)
- One topic never appears in two lanes. The peak focus band and out-of-hours work each emit *either* the positive card or the warning, never both.
- Comparative findings ("up from", "down from") require the preceding window of equal length and at least `recurrenceDays` of tracked history in it; without that, `WorkPatternReport.hasComparison` is false and those detectors stay silent rather than guess.
- `WorkPatternService` is pure — sessions in, insights out, no repositories and no clock of its own. All I/O belongs to `AnalyticsService`.

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

