# WorkPulse

## Implementation-Ready Product & Technical Specification

**Version:** V1.0  
**Platform:** macOS initially  
**Framework:** Flutter / Dart  
**Database:** SQLite  
**State Management:** Riverpod  
**Future Platform:** Windows

---

# 1. Product Definition

**WorkPulse** is a privacy-conscious, offline-first productivity and work-awareness application.

It allows a user to intentionally record:

- What they are working on
- Which project it belongs to
- Which category it belongs to
- Tags
- People involved
- Jira/reference metadata
- Individual work sessions
- Time spent on those sessions
- Periods of inactivity during sessions

The purpose is to help the user understand and improve how they spend their working time.

WorkPulse must **not** behave like employee surveillance software.

### Product positioning

> **WorkPulse — Understand your work. Improve your flow.**

---

# 2. Product Principles

## 2.1 Fast

The user should be able to start working on a task in seconds.

## 2.2 Minimal distraction

The primary interaction is a small keyboard-driven Quick Capture window.

## 2.3 Intentional tracking

The user explicitly starts tracking a task.

## 2.4 Privacy conscious

WorkPulse does not perform screen monitoring, keystroke logging, or application surveillance.

## 2.5 Local first

Core functionality works without internet connectivity.

## 2.6 Extensible

The architecture should support future Windows support and optional integrations without requiring a rewrite.

---

# 3. Technology Stack

## Application

- Flutter
- Dart

## UI

- Flutter / Material 3 where appropriate
- Custom lightweight desktop styling for Quick Capture

## State management

- Riverpod

## Persistence

- SQLite

Use a well-supported Flutter SQLite package.

The persistence layer must be abstracted behind repositories.

## Platform integration

Platform-specific services should be isolated behind interfaces.

### macOS V1

Native macOS implementation where required.

### Windows

Not implemented in V1, but interfaces must allow a Windows implementation later.

---

# 4. High-Level Architecture

```text
WorkPulse
│
├── Presentation
│   ├── Quick Capture
│   ├── Menu Bar
│   ├── Dashboard
│   ├── Tasks
│   ├── Projects
│   ├── Categories
│   └── Settings
│
├── Application
│   ├── Task Service
│   ├── Session Service
│   ├── Timer Service
│   ├── Idle Service
│   ├── Reporting Service
│   └── Search Service
│
├── Domain
│   ├── Task
│   ├── Session
│   ├── Project
│   ├── Category
│   ├── Tag
│   ├── Person
│   └── Idle Period
│
├── Persistence
│   ├── SQLite
│   └── Repositories
│
└── Platform
    ├── Global Shortcut
    ├── Window
    ├── Menu Bar
    ├── Notifications
    ├── Startup
    └── Idle Detection
```

Business logic must not directly depend on macOS APIs.

---

# 5. Platform Abstraction

Create interfaces for all OS-specific functionality.

Example:

```dart
abstract class GlobalShortcutService {
  Future<void> register();
  Future<void> unregister();
}
```

```dart
abstract class WindowService {
  Future<void> showQuickCapture();
  Future<void> hideQuickCapture();
  Future<void> focusQuickCapture();
}
```

```dart
abstract class SystemTrayService {
  Future<void> initialize();
  Future<void> update();
}
```

```dart
abstract class NotificationService {
  Future<void> show({
    required String title,
    required String message,
  });
}
```

```dart
abstract class SystemActivityService {
  Future<DateTime?> getLastUserActivity();
}
```

The application layer should depend on these abstractions rather than platform implementations.

---

# 6. Application Lifecycle

When WorkPulse starts:

1. Initialize SQLite.
2. Run database migrations.
3. Load application settings.
4. Initialize platform services.
5. Initialize menu-bar integration.
6. Register global keyboard shortcut.
7. Recover any active session.
8. Start idle detection if a session is active.
9. Keep WorkPulse primarily running as a background/menu-bar application.

The Dashboard should **not** automatically open.

The Quick Capture window should only appear when requested.

---

# 7. Quick Capture

Quick Capture is the most important UX component.

It should behave like a lightweight command palette.

Conceptually similar to:

- Spotlight
- Raycast
- Alfred

but focused specifically on WorkPulse tasks.

---

# 8. Global Shortcut

Default suggestion:

```text
Option + Space
```

The shortcut must be configurable.

It must work while the user is working in another application.

Invoking the shortcut should:

1. Bring Quick Capture to the foreground.
2. Give it keyboard focus.
3. Display the current task if one is active.
4. Otherwise display recent tasks / task creation UI.

---

# 9. Quick Capture Window

The window should be:

- Small
- Floating
- Keyboard-first
- Focused
- Non-distracting
- Fast to display
- Dismissible with Escape
- Automatically hidden after an action
- Always-on-top while active
- Visually consistent with macOS

The application should avoid opening a normal full-size window for this interaction.

---

# 10. New Task UI

When creating a new task, the UI has two conceptual levels.

## Primary information

The first line receives immediate keyboard focus:

```text
┌──────────────────────────────────────────────┐
│ 🔎  What are you working on?                 │
│                                              │
│ Fix authentication timeout                   │
├──────────────────────────────────────────────┤
│ Project   [ OpenText Platform       ▼ ]      │
│ Category  [ Engineering             ▼ ]      │
│ Tags      [ API, Bug                + ]      │
│ People    [ Richard                 + ]      │
│ Jira      [ PLAT-1234                 ]      │
│                                              │
│                     [ Cancel ] [ Start ]     │
└──────────────────────────────────────────────┘
```

The first line must have primary focus.

The secondary fields should be accessible through:

- Tab
- Shift+Tab
- Arrow keys where appropriate
- Mouse

Project and Category are mandatory before starting a new task.

Tags, people and Jira ID are optional.

---

# 11. Task Creation Workflow

Example:

```text
⌥ Space
↓
Type task
↓
Select project
↓
Select category
↓
Optional metadata
↓
Start
```

The UI must minimise the number of keystrokes required.

If the user enters a new project/category name, the application may provide an option to create it inline.

---

# 12. Existing Task Workflow

Quick Capture must also act as a task search/resume interface.

Example:

```text
┌──────────────────────────────────────────────┐
│ 🔎 architecture                              │
├──────────────────────────────────────────────┤
│ Architecture proposal       2h 50m           │
│ API architecture review     1h 20m           │
│ Architecture documentation  3h 10m           │
└──────────────────────────────────────────────┘
```

Search should cover:

- Task name
- Project
- Category
- Tags
- People
- Jira ID

---

# 13. Recent Tasks

When no search query exists, display:

1. Currently active task
2. Recently used tasks
3. Frequently used tasks
4. New Task

Example:

```text
Current
▶ Architecture proposal       01:23:42

Recent
  Production issue             1h 25m
  API redesign                 4h 12m
  AI strategy                  2h 40m

+ New Task
```

---

# 14. One Active Task Rule

Only **one active session** is permitted at any time.

WorkPulse must never intentionally run two active timers simultaneously.

This simplifies:

- UX
- Reporting
- Data integrity
- Idle handling
- Session management

---

# 15. Starting a Session

Starting a task creates a new Session.

A session contains:

```text
id
taskId
startTime
endTime
createdAt
```

The timer displayed to the user is calculated from timestamps.

Do not treat an incrementing counter as the authoritative duration.

---

# 16. Stopping a Session

The user selects Stop.

The application:

1. Records end timestamp.
2. Calculates duration.
3. Persists the session.
4. Removes the active session.
5. Updates menu-bar state.
6. Returns to the previous application.

There must be **no mandatory post-stop prompt**.

The user should be able to continue working immediately.

---

# 17. Task Switching

If the user selects another task while a task is active:

Do **not** switch immediately.

Show confirmation.

Example:

```text
┌────────────────────────────────────────┐
│ Switch task?                           │
│                                        │
│ Current                                │
│ Architecture proposal   01:23:42       │
│                                        │
│ Switch to                              │
│ Production issue                      │
│                                        │
│       [ Cancel ]     [ Switch ]        │
└────────────────────────────────────────┘
```

If confirmed:

1. End current session.
2. Persist current session.
3. Start a new session.
4. Set new task as active.
5. Close Quick Capture.

If cancelled:

- Continue current session unchanged.

---

# 18. Resume

Selecting a previously stopped task creates a new session.

Example:

```text
Task: Architecture proposal

Session 1    10:00 → 11:15    1h 15m
Session 2    14:00 → 14:45      45m
Session 3    16:30 → 17:20      50m

Total                         2h 50m
```

Sessions must remain individually visible in reporting/history.

---

# 19. Idle Detection

WorkPulse should detect user inactivity.

However, it must **not silently modify tracked time**.

When an idle period is detected, WorkPulse should notify the user.

Example:

```text
You've been inactive for 38 minutes.

What happened?

[ Keep Tracking ]
[ Mark as Idle ]
[ Stop Session ]
```

The user chooses the action.

---

# 20. Idle Period Model

An idle period should be associated with the active session.

Example:

```text
Session
09:00 → 12:00

Idle
10:15 → 10:45
```

The system should retain the information needed to calculate:

- Gross session duration
- Idle duration
- Active/adjusted duration

Do not automatically delete or modify the original session timestamps.

---

# 21. Task

A Task contains:

```text
id
name
projectId
categoryId
jiraId
notes
createdAt
updatedAt
lastWorkedAt
```

Tags and people should be represented through relationships rather than hard-coded fields.

---

# 22. Project

A Project contains:

```text
id
name
description
createdAt
updatedAt
archivedAt
```

Projects are independent from categories.

---

# 23. Category

A Category contains:

```text
id
name
description
createdAt
updatedAt
archivedAt
```

Categories are independent from projects.

Example:

```text
Project: OpenText Platform
Category: Architecture
```

and:

```text
Project: AI Productivity
Category: Architecture
```

This allows cross-project reporting by category.

---

# 24. Tags

Tags are reusable.

Example:

- Deep Work
- Meeting
- Call
- Customer
- Internal
- Urgent
- Architecture
- Review

A many-to-many relationship should exist between Tasks and Tags.

---

# 25. People

People are reusable entities.

A person can be associated with:

- A task
- A specific session

Because the user selected **session-level and task-level people**, support both.

Example:

```text
Task
API redesign

Task People:
Richard
John

Session 1:
Richard

Session 2:
John
Sarah
```

This allows more accurate reporting later.

---

# 26. Jira Metadata

V1 does not require Jira API integration.

Task metadata:

```text
Jira ID: PLAT-1234
```

The Jira ID must be:

- Searchable
- Displayed in task details
- Included in reports
- Included in exports

Optionally support a configurable Jira base URL for generating a link.

No network request should be necessary to use the Jira field.

---

# 27. Menu Bar

WorkPulse should primarily operate from the macOS menu bar.

Example:

```text
WorkPulse    ⏱ 01:23:42
```

Menu:

```text
Current Task
Architecture proposal
01:23:42

Stop
Switch Task
Quick Capture

Dashboard
Tasks
Reports

Settings
Quit
```

The menu-bar implementation must be isolated behind the platform abstraction.

---

# 28. Dashboard

V1 dashboard should be implemented entirely in Flutter.

Do **not** start a local web server in V1.

The Dashboard should be accessible from:

- Menu-bar menu
- Quick Capture
- Main WorkPulse window

---

# 29. Dashboard Views

## Today

Display:

- Total tracked time
- Active/adjusted time where available
- Time by project
- Time by category
- Time by task
- Session count
- Task-switch count

## This Week

Display the same metrics across the current week.

## Custom Range

Allow:

- Start date
- End date

---

# 30. Reporting

Reports should support grouping by:

### Project

```text
OpenText Platform       18h 42m
AI Productivity          7h 20m
```

### Category

```text
Engineering              15h
Architecture              6h
Meetings                  8h
```

### Task

```text
Architecture proposal    2h 50m
API redesign              4h 12m
```

### Person

```text
Richard                   3h 20m
John                      2h 15m
```

### Tag

```text
Deep Work                12h
Meeting                   7h
```

---

# 31. Productivity Metrics

The application may calculate:

- Longest session
- Average session duration
- Number of sessions
- Task switches
- Deep-work time
- Meeting time
- Call time
- Idle time
- Most productive day
- Most productive period

Do not make assumptions that a particular activity is "productive" unless the user has classified it accordingly.

---

# 32. Data Model

Recommended SQLite schema:

```text
projects
categories
tags
people
tasks
task_tags
task_people
sessions
session_people
idle_periods
settings
```

### sessions

```text
id
task_id
start_time
end_time
created_at
```

### idle_periods

```text
id
session_id
start_time
end_time
resolution
```

Where `resolution` may contain:

```text
keep_tracking
mark_idle
stop_session
```

---

# 33. Active Session Recovery

When WorkPulse launches:

1. Check for an unfinished session.
2. If none exists, continue normally.
3. If one exists, recover it.
4. Recalculate elapsed time from timestamps.
5. Restart idle detection.
6. Display the active task in the menu bar.

The application must not lose an active session because of:

- Application crash
- Force quit
- System restart
- Mac sleep
- Mac wake

---

# 34. Sleep/Wake

Timers must be timestamp-based.

Example:

```text
Start:       09:00
Mac sleeps:  10:00
Wake:        11:30
```

The session should reflect the actual elapsed wall-clock interval.

Idle detection can subsequently ask the user how the inactive period should be classified.

---

# 35. Historical Editing

Users can edit historical sessions.

Support:

- Start time
- End time
- Task
- Project
- Category
- Tags
- People
- Jira ID

Users can delete sessions.

Historical edits must recalculate reporting results.

---

# 36. Search

Global search should cover:

- Tasks
- Projects
- Categories
- Tags
- People
- Jira IDs

Search should be fast enough to support Quick Capture interaction without noticeable delay.

---

# 37. Export

V1 should support:

- CSV
- JSON

CSV:

```text
Date
Project
Category
Task
Tags
People
Jira ID
Session Start
Session End
Duration
Idle Duration
```

---

# 38. Backup

Full backup/restore is **not required for V1**.

The architecture should not prevent it from being added later.

The database should remain portable enough that a future backup feature can package:

- Database
- Settings
- Metadata

---

# 39. Network Policy

WorkPulse does **not** require strict zero-network behaviour.

However:

> Core tracking functionality must never require network access.

Future optional functionality may include:

- Jira integration
- Cloud backup
- Sync
- AI services
- Remote dashboards

Any such functionality must be:

- Explicitly enabled
- Clearly visible
- Disabled by default
- Independent from core tracking

V1 should make **no network requests**.

---

# 40. No Surveillance

WorkPulse V1 must NOT implement:

- Screen recording
- Screenshots
- Keystroke logging
- Webcam monitoring
- Microphone monitoring
- Application usage tracking
- Browser history tracking
- Hidden background activity collection

Idle detection should only determine whether the user appears inactive for the purpose of asking how to classify the current session.

---

# 41. Flutter Project Structure

Recommended structure:

```text
lib/
│
├── core/
│   ├── database/
│   ├── errors/
│   ├── routing/
│   ├── theme/
│   ├── utils/
│   └── platform/
│
├── domain/
│   ├── models/
│   ├── repositories/
│   └── services/
│
├── data/
│   ├── database/
│   ├── repositories/
│   └── migrations/
│
├── features/
│   ├── quick_capture/
│   ├── timer/
│   ├── sessions/
│   ├── tasks/
│   ├── projects/
│   ├── categories/
│   ├── tags/
│   ├── people/
│   ├── dashboard/
│   ├── reports/
│   └── settings/
│
└── main.dart
```

---

# 42. State Management

Use Riverpod.

Important application states include:

```text
NoActiveTask
StartingTask
TaskActive
StoppingTask
SwitchConfirmation
IdleDetected
ResolvingIdle
```

The timer state must have a single source of truth.

---

# 43. Timer State Machine

Recommended state machine:

```text
                    ┌──────────────┐
                    │              │
                    ▼              │
              ┌───────────┐       │
              │   IDLE    │       │
              └─────┬─────┘       │
                    │ Start       │
                    ▼             │
              ┌───────────┐       │
              │  ACTIVE   │───────┘
              └─────┬─────┘
                    │
            inactivity detected
                    │
                    ▼
              ┌───────────┐
              │IDLE PROMPT│
              └─────┬─────┘
             ┌──────┼──────┐
             │      │      │
             ▼      ▼      ▼
           Keep   Mark   Stop
          Tracking Idle  Session
             │      │      │
             └──┬───┘      ▼
                │        IDLE
                ▼
              ACTIVE
```

Task switching:

```text
ACTIVE Task A
      │
      ▼
Select Task B
      │
      ▼
Switch Confirmation
      │
      ├── Cancel → Task A remains ACTIVE
      │
      └── Confirm
             │
             ▼
       End Session A
             │
             ▼
       Start Session B
```

---

# 44. Quick Capture State Machine

```text
Closed
  │
  │ Global Shortcut
  ▼
Opened
  │
  ├── Search Existing Task
  │        │
  │        └── Select → Switch/Resume
  │
  └── Create New Task
           │
           ▼
      Task Name
           │
           ▼
      Project
           │
           ▼
      Category
           │
           ▼
      Optional Metadata
           │
           ▼
         Start
           │
           ▼
         Closed
```

---

# 45. Keyboard UX

Primary keyboard interactions:

```text
Global Shortcut
    Open Quick Capture

Enter
    Primary action

Escape
    Close/cancel

Tab
    Next field

Shift + Tab
    Previous field

Arrow Up/Down
    Navigate search results

Cmd/Ctrl + Enter
    Optional alternative Start action
```

Exact shortcuts should be configurable where appropriate.

---

# 46. Performance Requirements

Quick Capture should appear in:

**<300 ms perceived response time** under normal conditions.

Database searches should feel instantaneous for normal personal datasets.

Avoid loading the entire database into memory.

Use indexed database queries where appropriate.

The background application should consume minimal CPU when no active operation is occurring.

---

# 47. Testing Requirements

## Unit tests

Test:

- Session duration
- Task switching
- Resume
- Idle periods
- Date boundaries
- Sleep/wake
- Reporting
- Aggregation
- Search

## Repository tests

Test:

- Task CRUD
- Project CRUD
- Category CRUD
- Tag relationships
- People relationships
- Session lifecycle
- Idle lifecycle

## Widget tests

Test:

- Quick Capture
- New task
- Existing task search
- Keyboard navigation
- Switch confirmation
- Idle prompt

## Integration tests

At minimum:

```text
Create Task
→ Start
→ Stop
→ Resume
→ Stop
→ Report
```

and:

```text
Task A active
→ Select Task B
→ Cancel
→ Task A remains active
```

and:

```text
Task A active
→ Select Task B
→ Confirm
→ Task A stopped
→ Task B started
```

---

# 48. Development Strategy for AI Coding

Do NOT ask an AI coding agent to generate the complete application in one step.

Build in vertical slices.

## Sprint 1 — Project foundation

Implement:

- Flutter project
- Architecture
- Riverpod
- SQLite
- Database migrations
- Basic domain models

Deliverable:

> Application launches and can persist data.

---

## Sprint 2 — Tasks

Implement:

- Projects
- Categories
- Tasks
- Task search
- Basic CRUD

Deliverable:

> User can create and search tasks.

---

## Sprint 3 — Timer

Implement:

- Active session
- Start
- Stop
- Resume
- One-active-task rule
- Timestamp-based duration

Deliverable:

> Core time tracking works reliably.

---

## Sprint 4 — Quick Capture

Implement:

- Floating window
- Global shortcut
- Keyboard navigation
- New task flow
- Existing task flow

Deliverable:

> User can start/resume a task without leaving their current application.

---

## Sprint 5 — Task Switching

Implement:

- Task selection
- Confirmation
- Stop current session
- Start new session

Deliverable:

> Fast, safe task switching.

---

## Sprint 6 — Metadata

Implement:

- Tags
- People
- Jira ID
- Task-level people
- Session-level people

Deliverable:

> Tasks contain useful context.

---

## Sprint 7 — Idle Detection

Implement:

- Inactivity detection
- Idle prompt
- Keep tracking
- Mark idle
- Stop

Deliverable:

> Inactivity is handled without silently changing data.

---

## Sprint 8 — macOS Integration

Implement:

- Menu bar
- Startup
- Notifications
- Window management
- Global shortcut

Deliverable:

> WorkPulse behaves like a proper macOS utility.

---

## Sprint 9 — Dashboard

Implement:

- Today
- Week
- Project breakdown
- Category breakdown
- Task breakdown
- Session history

Deliverable:

> User can understand where their time is going.

---

## Sprint 10 — Reports & Export

Implement:

- Charts
- People reporting
- Tags
- CSV
- JSON

Deliverable:

> User can analyse and export their data.

---

# 49. Explicitly Out of Scope for V1

Do NOT implement:

- Cloud synchronization
- User accounts
- Authentication
- Online database
- Local web dashboard
- Jira API
- Calendar integration
- Slack integration
- Teams integration
- AI-generated insights
- Automatic task classification
- Automatic application categorisation
- Screen monitoring
- Screenshot capture
- Keystroke logging
- Multi-user support
- Windows support

The architecture should allow these later, but V1 should not contain them.

---

# 50. Future Windows Architecture

When Windows support begins, the expected architecture is:

```text
                 Shared Flutter Application
                          │
              ┌───────────┴───────────┐
              │                       │
           macOS                   Windows
              │                       │
       Native Platform          Native Platform
          Services                 Services
```

The following should have platform-specific implementations:

- Global shortcut
- System tray
- Window management
- Startup
- Notifications
- Idle detection

The following should remain shared:

- UI
- Domain
- Database
- Timer
- Sessions
- Reporting
- Search
- Analytics
- Export

---

# 51. Definition of Done for V1

V1 is successful when a user can:

1. Install WorkPulse on a Mac.
2. Start it as a menu-bar application.
3. Press a global shortcut from any application.
4. Create a task.
5. Select a project.
6. Select a category.
7. Add optional metadata.
8. Start tracking.
9. Return immediately to their previous application.
10. Reopen Quick Capture.
11. Search existing tasks.
12. Select another task.
13. Receive a switch confirmation.
14. Confirm or cancel the switch.
15. Stop a task without a follow-up prompt.
16. Resume a task later.
17. See every session separately.
18. Handle inactivity through an explicit user choice.
19. View daily/weekly reports.
20. Search historical work.
21. Export data.
22. Use all core functionality without internet access.
23. Recover correctly after application restart or Mac sleep/wake.

---

# 52. Primary UX Success Criterion

WorkPulse must never feel like a timesheet application.

The ideal workflow is:

```text
⌥ Space
     ↓
Type / select
     ↓
Choose project + category
     ↓
Enter
     ↓
Back to work
```

For an existing task:

```text
⌥ Space
     ↓
Search/select
     ↓
Confirm switch if required
     ↓
Back to work
```

The interaction should take **seconds**, not minutes.

---

# 53. AI Agent Guardrails

When implementing WorkPulse, the coding agent must:

1. Implement one sprint at a time.
2. Do not implement future features unless explicitly requested.
3. Do not introduce cloud dependencies.
4. Keep platform-specific code isolated.
5. Keep domain logic independent of Flutter widgets.
6. Keep database access behind repositories.
7. Write tests for business logic.
8. Use migrations for database schema changes.
9. Never silently alter historical tracking data.
10. Never silently discard idle time.
11. Never allow multiple active sessions.
12. Keep Quick Capture keyboard-first.
13. Prefer simple solutions over unnecessary abstractions.
14. Maintain Apple Silicon compatibility.
15. Preserve a clear path to Windows support.
16. Document significant architectural decisions.

---

# 54. Final Technical Direction

The V1 architecture is:

```text
             ┌───────────────────────┐
             │       WorkPulse       │
             │       Flutter         │
             └───────────┬───────────┘
                         │
             ┌───────────▼───────────┐
             │       Riverpod        │
             │    Application State  │
             └───────────┬───────────┘
                         │
             ┌───────────▼───────────┐
             │      Domain Layer     │
             │ Tasks / Sessions / etc│
             └───────────┬───────────┘
                         │
             ┌───────────▼───────────┐
             │      Repository       │
             │         Layer         │
             └───────────┬───────────┘
                         │
             ┌───────────▼───────────┐
             │        SQLite         │
             └───────────────────────┘

              Platform Abstraction
                     │
          ┌──────────┴──────────┐
          │                     │
       macOS V1             Windows Later
```

The **critical V1 experience** is the Quick Capture workflow. Everything else should support that experience rather than compete with it.

The application should feel like:

> **A tiny productivity pulse sitting quietly in your menu bar, available whenever you need it.**