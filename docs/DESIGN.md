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
5. **Fast Keyboard-First Quick Capture with Focus Isolation**: Floating command palette appearing in `<300ms` perceived response time over any focused application without stealing or exposing full dashboard application focus.

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
│   (SQLite Tables, Migrations V1-V4, Concrete Repositories)│
└─────────────────────────────┬─────────────────────────────┘
                              │
┌─────────────────────────────▼─────────────────────────────┐
│                      Core & Platform                      │
│   (Database Manager, Native Bridges, Hotkey & Tray API)   │
└───────────────────────────────────────────────────────────┘
```

### Layer Details:
- **`lib/core/`**: Platform adapters (`HotKeyService`, `TrayService`, `IdleDetectorService`, `SystemIdleSource`, `WindowService`), database initialization, error types (`AppException`), the design system (`WorkPulseColors`, `design_tokens.dart`, `core/widgets/`), and the keyboard layer (`core/keyboard/`: platform shortcut labels and the search-focus registry).
- **`lib/domain/`**: Pure Dart models (`WorkItem`, `Session`, `Project`, `Category`, `Tag`, `Person`, `AttributeDefinition`, `AttributeOption`, `IdlePeriod`), repository contracts, and business logic services (`TimerService`, `TaskSwitchService`, `IdleService`).
- **`lib/data/`**: SQLite table schemas (`Tables`), versioned migrations (`MigrationV1`–`MigrationV4`), DAOs, and repository implementations (`SqliteWorkItemRepository`, `SqliteSessionRepository`, etc.).
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

### Migration History:
- **`MigrationV1`**: Schema creation (16 tables), indices, and default workspace seeding.
- **`MigrationV2`**: Adds `notes` column to `sessions` table, enabling granular session-level work notes and task switch handover descriptions.

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
              ├── Stop Session A (commit endTime and optional session notes in SQLite)
              ├── Start Session B (commit startTime in SQLite)
              └── Update macOS Menu Bar & In-App Top Timer Bar
```

### 4.2. Inactivity & Idle Resolution Flow

Unaccounted time reaches the same prompt from two independent detectors, because
they fail in opposite ways: the live poller only sees time that passes while the
process is running, and the startup check only sees time that passed while it
was not.

```text
[Tracking Session] ──(No input for > threshold)────────┐
                                                       │
[App Launch] ──(open session + heartbeat gap)──────────┤
                                                       ▼
                                              [Idle Prompt Dialog]
                                                        │
         ┌──────────────────────────────┬───────────────┴──────────────┐
         ▼                              ▼                              ▼
  [Keep Tracking]                [Mark as Idle]                 [Stop Session]
  (Resolution logged)            (Idle period logged,           (Session ended at
  (Session continues)             duration deducted)             idle start time)
```

**Live inactivity** (`IdleDetectorService`) polls elapsed time against the idle
threshold while WorkPulse runs.

**Unaccounted gaps** (`ActivityHeartbeatService` + `IdleGapService`) cover the
case the poller structurally cannot: quitting the app, logging out, or shutting
the Mac down with a timer left running. The poll loop dies with the process,
while `sessions.end_time` stays `NULL` and duration keeps accruing off
wall-clock — so the next launch would silently show hours nobody worked.

While a session is running, WorkPulse writes a `last_activity_heartbeat_at`
timestamp to the `settings` table every 30s, plus on every app lifecycle change.
On the next launch, `IdleGapService` compares that heartbeat against now:

- The gap starts at the last heartbeat, or at `session.start_time` when no
  heartbeat covers the session (fresh install, or an upgrade from a build that
  never wrote one) — always the honest lower bound on unverified time.
- A gap at or above the idle threshold raises the prompt with
  `IdleTrigger.appNotRunning`, which only changes the wording; all three
  resolutions behave identically.
- The heartbeat is re-baselined once a prompt is resolved, and deliberately
  held back while one is open, so a force-quit mid-prompt does not erase the
  very gap the user has not answered for yet.

---

## 5. Desktop Native Integrations & Window Modes

macOS is the primary target and Windows is a supported one. All native OS
bindings sit behind interfaces in `lib/core/platform/`, each with a fallback
that no-ops (or reports "cannot answer") where a platform lacks the capability,
so a missing native path degrades rather than crashes.

| Concern | macOS | Windows | Linux |
| :--- | :--- | :--- | :--- |
| Global hotkey | `hotkey_manager` | `hotkey_manager` | `hotkey_manager` |
| Tray / menu bar | icon **and** live title ticker | icon, tooltip, context menu | icon, tooltip, context menu |
| Window & HUD | `window_manager` + `screen_retriever` | same | same |
| System idle time | `CGEventSourceSecondsSinceLastEventType` (FFI) | `GetLastInputInfo` (FFI) | **unavailable** — never prompts |
| Open an export | `open` | `cmd /c start` | `xdg-open` |
| Reveal an export | `open -R` (Finder) | `explorer /select,` | `xdg-open` on the folder |
| Packaging | `.app` bundle, sandboxed | `Release/` directory | not configured |

`tray_manager` only supports a *titled* tray item on macOS, so the live
`⏱ 00:14:22  Task Name` ticker is macOS-only by platform convention; on Windows
the same information is carried by the tooltip and the context menu.

- **`HotKeyService`**: Handles system-wide `⌥ + Space` / `Alt + Space` registration via `hotkey_manager`. The binding is user-configurable and persisted; `NoOpHotKeyService` stands in for tests.
- **`TrayService`**: Manages the tray icon, the macOS live status bar ticker (`⏱ 00:14:22  Task Name`), and the context menu via `tray_manager`. `TrayCoordinator` owns every menu action; quitting from it writes a final heartbeat and closes the database before exiting, so the next launch does not attribute the shutdown moment to unaccounted time.
- **`WindowService` & Window Modes**:
  - **`WindowMode.quickCapture`**:
    - Invoked via global shortcut `⌥ + Space` or Tray "Quick Capture".
    - Transforms the Flutter window into a frameless, transparent (`#00000000`), `alwaysOnTop` floating HUD (`660x440`).
    - Positioned in the upper third of the monitor containing the active mouse cursor via `screen_retriever`.
    - Renders `QuickCaptureStandaloneView` without bringing the full dashboard window into focus.
    - Features `onWindowBlur` auto-dismissal: clicking outside or switching apps hides the HUD and returns focus cleanly to the previous application.
  - **`WindowMode.dashboard`**:
    - Restores standard window decorations (`TitleBarStyle.normal`), disables `alwaysOnTop`, and expands to full dashboard dimensions (`1200x800` or saved bounds).
    - Top header hosts `ActiveTimerBar` with pulsing status indicator, project badge, live monospace duration ticker, and quick Switch / Stop actions.
- **`IdleDetectorService`**: Polls `SystemIdleSource` — the OS's own "seconds since last input" counter — every 10 seconds while a session runs, and raises one event per uninterrupted idle stretch once the user's configured threshold (3–30 minutes, default 10) is crossed. It queries an aggregate the OS already maintains; it never observes input itself. See [ADR 001](adr/001-system-idle-detection.md) for why, and for the defect this replaced.
