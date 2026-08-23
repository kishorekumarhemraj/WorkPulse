# WorkPulse — Technical Design & Architecture Specification

**Document:** `docs/DESIGN.md`  
**Platform:** macOS (First-class desktop app built with Flutter & Dart)  
**State Management:** Riverpod 3.x  
**Storage:** Local SQLite (`sqflite_common_ffi`)  

---

## 1. System Overview

WorkPulse is an intentional, privacy-first desktop utility for work awareness and time tracking. It runs locally on macOS, requiring zero network connectivity, screen recording, or telemetry.

### Core Architectural Invariants:
1. **Zero Hardcoded External Tools**: No Jira, ServiceNow, or Azure DevOps specific fields in the core schema. All custom metadata is driven by configurable attribute definitions.
2. **One and Only One Active Session**: Exactly one work session can run at any moment. Switching tasks cleanly stops and commits the previous session.
3. **Wall-Clock Truth**: Durations are calculated as `end_time - start_time`. In-memory timers are visual representations only.
4. **Soft-Archiving**: Referenced entities (projects, categories, attributes) are archived via `archived_at` to guarantee historical data integrity.
5. **Fast Keyboard-First Quick Capture**: Floating command palette appearing in `<300ms` perceived response time.

---

## 2. Layered Architecture

WorkPulse strictly adheres to a 4-layer clean architecture:

```text
┌───────────────────────────────────────────────────────────┐
│                      Presentation Layer                    │
│   (Flutter Widgets, Riverpod Notifiers, Floating UI)      │
└─────────────────────────────┬─────────────────────────────┘
                              │
┌─────────────────────────────▼─────────────────────────────┐
│                        Domain Layer                       │
│    (Pure Dart Entities, Repository Interfaces, Services)   │
│           * Zero Flutter & Zero SQLite imports *          │
└─────────────────────────────┬─────────────────────────────┘
                              │
┌─────────────────────────────▼─────────────────────────────┐
│                         Data Layer                        │
│    (SQLite Tables, Migration V1, Concrete Repositories)   │
└─────────────────────────────┬─────────────────────────────┘
                              │
┌─────────────────────────────▼─────────────────────────────┐
│                      Core & Platform                      │
│   (Database Manager, Native Bridges, Hotkey & Tray API)   │
└───────────────────────────────────────────────────────────┘
```

### Layer Details:
- **`lib/core/`**: Platform adapters (`HotKeyService`, `TrayService`, `IdleDetectorService`, `WindowService`), database initialization, error types (`AppException`), and color/icon utilities.
- **`lib/domain/`**: Pure Dart models (`WorkItem`, `Session`, `Project`, `Category`, `Tag`, `Person`, `AttributeDefinition`, `AttributeOption`, `IdlePeriod`), repository contracts, and business logic services (`TimerService`, `TaskSwitchService`, `IdleService`).
- **`lib/data/`**: SQLite table schemas (`Tables`), versioned migrations (`MigrationV1`), DAOs, and repository implementations (`SqliteWorkItemRepository`, `SqliteSessionRepository`, etc.).
- **`lib/features/`**: Feature-specific UI, view models, and Riverpod providers (`quick_capture/`, `tasks/`, `timer/`, `idle/`, `attributes/`, `projects/`, `categories/`, `tags/`, `people/`, `dashboard/`, `reports/`, `settings/`, `shell/`).

---

## 3. SQLite Database Schema & Entity Relationships

The schema consists of 16 normalized tables configured with `PRAGMA foreign_keys = ON;`:

```text
               ┌─────────────┐
               │ workspaces  │
               └──────┬──────┘
                      │ 1:N
        ┌─────────────┼─────────────┬─────────────┐
        ▼             ▼             ▼             ▼
  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐
  │ projects  │ │categories │ │   tags    │ │  people   │
  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘
        │ 1:N         │ 1:N         │ M:N         │ M:N
        └─────────────┼─────────────┼─────────────┘
                      ▼
               ┌─────────────┐
               │ work_items  │◄───────────────────────┐
               └──────┬──────┘                        │
                      │ 1:N                           │ 1:N
                      ▼                               │
               ┌─────────────┐            ┌───────────┴──────────────┐
               │  sessions   │            │work_item_attribute_values│
               └──────┬──────┘            └──────────────────────────┘
                      │ 1:N                           ▲
                      ├──────────────────────────┐    │
                      ▼                          ▼    │
               ┌─────────────┐    ┌──────────────┴────┴───────┐
               │idle_periods │    │   attribute_definitions   │
               └─────────────┘    └──────────────┬────────────┘
                                                 │ 1:N
                                                 ▼
                                  ┌───────────────────────────┐
                                  │     attribute_options     │
                                  └───────────────────────────┘
```

### Key Performance Indices:
- `idx_work_items_name` on `work_items(name)`
- `idx_work_items_project_id` on `work_items(project_id)`
- `idx_work_items_category_id` on `work_items(category_id)`
- `idx_work_items_last_worked` on `work_items(last_worked_at)`
- `idx_sessions_work_item_id` on `sessions(work_item_id)`
- `idx_sessions_start_time` on `sessions(start_time)`
- `idx_sessions_end_time` on `sessions(end_time)`
- `idx_idle_periods_session_id` on `idle_periods(session_id)`
- `idx_attr_def_workspace_key` on `attribute_definitions(workspace_id, key)`

---

## 4. State Machines & Key Workflows

### 4.1. Single Active Session & Switching Flow
```text
[No Active Session]
       │
       │ Start WorkItem A
       ▼
[Session A Active (WorkItem A)]
       │
       │ User selects WorkItem B (in Quick Capture or Shell)
       ▼
[Switch Confirmation Dialog]
       ├── Cancel ──> Resume Session A Active
       └── Confirm
              │
              ├── Stop Session A (commit endTime in SQLite)
              ├── Start Session B (commit startTime in SQLite)
              └── Update Menu Bar & Active Timer Bar
```

### 4.2. Inactivity & Idle Resolution Flow
```text
[Tracking Session] ──(No input for > 10 min)──> [Idle Prompt Dialog]
                                                        │
         ┌──────────────────────────────┬───────────────┴──────────────┐
         ▼                              ▼                              ▼
  [Keep Tracking]                [Mark as Idle]                 [Stop Session]
  (Resolution logged)            (Idle period logged,           (Session ended at
  (Session continues)             duration deducted)             idle start time)
```

---

## 5. macOS Native Integrations

All native OS bindings are abstracted behind clean interfaces to ensure testability:
- **`HotKeyService`**: Handles system-wide `⌥ + Space` (Option + Space) registration via `hotkey_manager`.
- **`TrayService`**: Manages menu bar icon, dynamic title (`⏱ 01:23:42`), and context menu via `tray_manager`.
- **`WindowService`**: Controls multi-window behaviors, centering Quick Capture on focused display screen via `screen_retriever` and `window_manager`.
- **`IdleDetectorService`**: Dispatches inactivity alerts based on user input thresholds.
