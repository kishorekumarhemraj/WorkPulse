# WorkPulse — Product & Technical Specification

**Document:** `docs/WORKPULSE_SPEC.md`  
**Version:** 1.0  
**Status:** Implementation baseline  
**Initial platform:** macOS  
**Framework:** Flutter / Dart  
**Database:** SQLite  
**State management:** Riverpod  
**Future platform:** Windows

---

## 1. Product Vision

**WorkPulse** is a privacy-conscious productivity and work-awareness application that helps users understand how they spend their working time.

The user intentionally records:

- What they are working on
- Which project it relates to
- How the work is categorised
- Relevant tags
- People involved
- Optional organisation-specific metadata
- Individual work sessions
- Time spent on those sessions
- Periods of inactivity

The application should feel like a **personal productivity utility**, not a timesheet or employee-monitoring system.

### Positioning

> **WorkPulse — Understand your work. Improve your flow.**

---

## 2. Core Product Principles

### Fast

Starting or switching work should take seconds.

### Low distraction

The primary interaction is a small keyboard-driven floating window.

### Intentional

The user explicitly starts tracking a work item.

### Privacy-conscious

No screen recording, keystroke logging, browser monitoring, or application surveillance.

### Offline-first

Core functionality requires no network connection.

### Configurable

Organisation-specific concepts must not be hardcoded into the application.

### Extensible

The architecture must support Windows and future integrations without redesigning the core domain.

---

## 3. Important Terminology

Internally, the core domain should use **WorkItem** rather than assuming everything is a conventional "task".

A WorkItem could represent:

- Software development
- Architecture work
- A meeting
- A customer call
- Planning
- Research
- Code review
- Documentation
- Administration

The UI may use **Task** where that is more natural for users.

Conceptually:

```text
WorkItem
   │
   ├── Project
   ├── Category
   ├── Tags
   ├── People
   ├── Custom Attributes
   │
   └── Sessions
          └── Idle Periods
```

---

## 4. Core Domain Model

The following are **first-class WorkPulse concepts**:

```text
Workspace
WorkItem
Project
Category
Tag
Person
Session
IdlePeriod
AttributeDefinition
AttributeOption
```

The following are **not** first-class concepts:

```text
Jira
Azure DevOps
ServiceNow
Customer
Release
Environment
Ticket
```

Those are examples of configurable attributes.

---

## 5. WorkItem

A WorkItem represents something the user spends time working on.

Example:

```text
Architecture proposal
```

A WorkItem contains:

```text
id
name
projectId
categoryId
status
notes
createdAt
updatedAt
lastWorkedAt
archivedAt
```

It can have relationships to:

```text
Tags
People
Custom Attributes
Sessions
```

---

## 6. WorkItem Lifecycle

Stopping a timer does **not** complete the WorkItem.

These are independent concepts.

### WorkItem status

```text
Active
Completed
Archived
```

### Session status

```text
Running
Completed
```

A WorkItem may have many sessions.

---

## 7. Project

Projects are first-class entities.

Examples:

```text
OpenText Platform
AI Productivity
Internal Engineering
Open Source
```

Project:

```text
id
name
description
createdAt
updatedAt
archivedAt
```

Projects should be archived rather than deleted when historical sessions reference them.

---

## 8. Category

Categories are independent classifications.

Examples:

```text
Engineering
Architecture
Meeting
Planning
Documentation
Support
Research
```

A category does **not** belong to a project.

This enables reporting such as:

> How much time did I spend on Architecture across all projects?

Category:

```text
id
name
description
createdAt
updatedAt
archivedAt
```

---

## 9. Tags

Tags are reusable and many-to-many.

Examples:

```text
Deep Work
Meeting
Call
Customer
Internal
Urgent
Review
```

Tags remain first-class concepts because they have different semantics from arbitrary attributes.

---

## 10. People

People are reusable entities.

A person can be associated with a WorkItem and/or individual Session.

Example:

```text
Architecture proposal
People:
Richard
John
```

A session can also have its own people associations.

---

## 11. Configurable Attributes

This is a fundamental architectural requirement.

> **Organisation-specific or workflow-specific information must never be hardcoded into the WorkPulse domain model.**

Examples:

```text
Jira ID
Customer
Release
Environment
Ticket
Team
Cost Centre
Work Type
Billable
Reference
```

are configurable attributes.

A user with no Jira configuration should never see "Jira" anywhere in WorkPulse.

---

## 12. Attribute Definition

```text
AttributeDefinition

id
key
name
description
type
scope
required
enabled
searchable
reportable
showInQuickCapture
showInTaskDetails
displayOrder
createdAt
updatedAt
archivedAt
```

### Key

Stable internal identifier.

Example:

```text
jira_id
```

### Name

User-facing name.

Example:

```text
Jira ID
```

The user can rename the display name without changing the internal key.

---

## 13. Attribute Scope

V1 should support:

```text
TASK
SESSION
```

The initial UI may expose custom attributes primarily at the WorkItem/Task level.

This leaves room for future attributes such as:

```text
Meeting Type → Session
Customer → WorkItem
Environment → WorkItem
```

---

## 14. Attribute Types

V1 supports:

### Text

```text
Jira ID
Customer
Reference
Ticket
```

### Number

```text
Story Points
Cost Centre
```

### Boolean

```text
Billable
Customer Facing
```

### Single Select

```text
Environment

Development
Testing
Staging
Production
```

### Multi Select

```text
Teams

Platform
Security
Mobile
```

### Date

```text
Release Date
```

Do not introduce additional types until there is a real use case.

---

## 15. Attribute Values

Do **not** store all custom metadata as an unstructured JSON blob.

Use a typed value model.

Recommended:

```text
attribute_definitions
attribute_options
work_item_attribute_values
session_attribute_values
```

This allows proper:

- Searching
- Filtering
- Reporting
- Validation
- Indexing
- Schema evolution

---

## 16. Attribute Lifecycle

Attributes must support:

```text
Enabled
Archived
```

Deleting an attribute must **not delete historical values**.

An archived attribute stops appearing for new work while historical data remains intact.

---

## 17. Attribute Type Changes

Arbitrary type changes should **not** be supported in V1.

For example, a Text attribute should not be converted directly to Single Select.

Instead:

1. Archive old attribute.
2. Create new attribute.

This avoids dangerous historical data conversions.

---

## 18. Required Attributes

Attributes can be:

```text
Required
Optional
```

Required means:

> A new WorkItem cannot be started without providing that attribute.

Historical WorkItems are never invalidated when a new attribute becomes required.

---

## 19. Quick Capture

Quick Capture is the most important UX.

It should behave like a command palette rather than a conventional application form.

Default shortcut:

```text
Option + Space
```

The shortcut must be configurable.

---

## 20. Quick Capture Window

Requirements:

- Small
- Floating
- Keyboard-first
- Fast
- Non-distracting
- Always-on-top while active
- Escape to dismiss
- Returns focus to previous application
- Does not open a full-size application window

---

## 21. New WorkItem UI

The UI has two levels.

### First line

Primary task/work description:

```text
What are you working on?

Fix authentication timeout
```

This field receives immediate keyboard focus.

### Second section

Secondary context:

```text
Project    [ OpenText Platform ▼ ]
Category   [ Engineering      ▼ ]

Tags       [ Bug, API         + ]
People     [ Richard          + ]
Jira ID    [ PLAT-1234          ]
```

The actual secondary fields are **configuration-driven**.

---

## 22. Quick Capture Attribute Visibility

Every configurable attribute can specify:

```text
showInQuickCapture
```

This prevents a 15-field configuration from turning Quick Capture into a giant form.

Recommended UX:

> Keep Quick Capture to roughly 3–5 secondary fields.

WorkPulse may warn the user if they configure substantially more.

Other metadata remains available in WorkItem Details.

---

## 23. New WorkItem Flow

```text
Option + Space
       ↓
Enter work description
       ↓
Select Project
       ↓
Select Category
       ↓
Optional configured metadata
       ↓
Start
```

Project and Category are mandatory in the initial configuration.

Tags, People and Custom Attributes are optional unless configured as required.

---

## 24. Existing WorkItem Search

Quick Capture also searches existing WorkItems.

Search across:

```text
WorkItem name
Project
Category
Tags
People
Custom attributes marked searchable
```

---

## 25. Current WorkItem

When a session is active, Quick Capture should prominently display it.

```text
CURRENT

Architecture proposal
01:23:42
```

The user can:

```text
Stop
Switch
Open Details
```

---

## 26. Task Switching

There can be only **one active session**.

If the user selects another WorkItem, WorkPulse asks for confirmation.

### Cancel

Current session remains active.

### Confirm

1. End current session.
2. Persist it.
3. Start new session.
4. Set new WorkItem as current.
5. Close Quick Capture.

---

## 27. Session

A Session represents one continuous period of tracking a WorkItem.

```text
Session

id
workItemId
startTime
endTime
createdAt
```

Duration is derived from timestamps.

Never use an incrementing timer counter as the authoritative data source.

---

## 28. Resuming Work

Selecting a previously used WorkItem creates a **new Session**.

Example:

```text
Architecture proposal

Session 1    09:00–10:15    1h 15m
Session 2    14:00–14:45      45m
Session 3    16:30–17:20      50m

Total                       2h 50m
```

Sessions remain individually visible.

---

## 29. Stopping

Stopping:

1. Records end timestamp.
2. Persists session.
3. Clears active session.
4. Updates menu bar.
5. Returns to previous application.

There is **no mandatory post-stop question**.

---

## 30. Start vs Save

WorkItem creation and time tracking are separate.

Task Details should eventually support:

```text
Save
Save & Start
```

Quick Capture remains focused on:

```text
Start
```

---

## 31. Idle Detection

WorkPulse should detect inactivity.

Default suggestion:

```text
10 minutes
```

The threshold must be configurable.

Important:

> Idle detection does not mean WorkPulse assumes the user wasn't working.

It only indicates:

> No detectable keyboard/mouse interaction occurred for the configured period.

---

## 32. Idle Prompt

Example:

```text
You've been inactive for 38 minutes.

What happened?

[ Keep Tracking ]
[ Mark as Idle ]
[ Stop Session ]
```

No action should silently destroy tracked time.

---

## 33. Idle Period

```text
IdlePeriod

id
sessionId
startTime
endTime
resolution
```

Resolution:

```text
keep_tracking
mark_idle
stop_session
```

Raw session timestamps should remain unchanged.

---

## 34. System Sleep

System sleep should be treated differently from normal inactivity.

WorkPulse should record sleep/wake information rather than automatically assuming the entire period was user idle.

The user can resolve the period appropriately.

---

## 35. Gross vs Active Time

WorkPulse should distinguish:

### Gross tracked time

```text
Session end - Session start
```

### Idle time

Time explicitly classified as idle.

### Active/adjusted time

```text
Gross time - Idle time
```

Example:

```text
Tracked: 8h 20m
Idle:      45m
Active:   7h 35m
```

The raw session timestamps remain the source of truth.

---

## 36. Crash Recovery

If WorkPulse crashes while a session is active:

1. Preserve the session.
2. Recover it on next launch.
3. Recalculate duration from timestamps.
4. Mark any application-unavailable interval as **unverified** where necessary.

Do not silently fabricate user activity.

---

## 37. Time, Timezones and Day Boundaries

Persist timestamps using a timezone-safe representation.

Prefer UTC internally and localise for display.

Handle:

- Timezone changes
- DST
- Manual clock changes
- Sleep/wake
- Day boundaries

A session can span multiple days.

Example:

```text
23:50 → 01:20
```

Reporting must allocate:

```text
Day 1: 10 minutes
Day 2: 1h 20m
```

---

## 38. Historical Editing

Users can edit historical sessions.

Editable:

- Start
- End
- WorkItem
- Project
- Category
- Tags
- People
- Custom attributes

Changes must immediately affect reporting.

---

## 39. Deletion Policy

Referenced entities should normally be archived.

Examples:

```text
Delete Project
      ↓
Archive Project
```

Historical sessions remain intact.

Permanent deletion should be a separate destructive operation.

The same principle applies to:

- WorkItems
- Projects
- Categories
- Tags
- People
- Attributes

---

## 40. Menu Bar

WorkPulse primarily operates from the macOS menu bar.

Example:

```text
◉ Architecture proposal   01:23:42
```

Menu:

```text
Current Work
Architecture proposal
01:23:42

Stop
Switch Work
Quick Capture

Dashboard
WorkItems
Reports

Settings

Quit
```

---

## 41. Dashboard

V1 uses a **Flutter desktop dashboard**.

No localhost web server in V1.

Dashboard accessible from:

- Menu bar
- Quick Capture
- Main WorkPulse window

---

## 42. Dashboard Views

### Today

- Total tracked time
- Active time
- Idle time
- Time by project
- Time by category
- Time by WorkItem
- Session count
- Task switches

### This Week

Same metrics across the week.

### Custom Range

User-selectable date range.

---

## 43. Reporting

Reports can group by first-class dimensions:

```text
Project
Category
WorkItem
Person
Tag
```

and configurable attributes marked:

```text
reportable = true
```

The reporting engine must not contain Jira-specific code.

---

## 44. Search

Global search should support:

- WorkItems
- Projects
- Categories
- Tags
- People
- Searchable custom attributes

Search should remain local and fast.

---

## 45. Workspace Configuration

First launch should provide a lightweight setup experience.

Default:

```text
Projects       Enabled
Categories     Enabled
Tags           Enabled
People         Enabled
Custom fields  None
```

Users can configure their workflow later.

---

## 46. Workflow Settings

Settings should contain:

```text
General
Tracking
Quick Capture
Workflow
Attributes
Projects
Categories
Tags
People
Data
```

Workflow configuration should be understandable to normal users.

Avoid database/schema terminology in the UI.

---

## 47. Attribute Configuration UI

Example:

```text
Workflow → Attributes

Name          Type          Required   Quick Capture

Jira ID       Text          No         ✓
Customer      Text          No         ✓
Environment   Select        No         ✓
Release       Text          No         —
Billable      Boolean       No         ✓

                       + Add Attribute
```

---

## 48. Select Options

Single/Multi-select attributes support configurable options.

Example:

```text
Environment

Development
Testing
Staging
Production

+ Add Option
```

---

## 49. Data Model

Recommended SQLite entities:

```text
workspaces

projects
categories
tags
people

work_items
work_item_tags
work_item_people

sessions
session_people

idle_periods

attribute_definitions
attribute_options
work_item_attribute_values
session_attribute_values

settings
```

Potential future entities:

```text
system_events
workspace_profiles
sync_metadata
```

---

## 50. Stable IDs

All major entities should use stable UUIDs.

This prepares the application for future:

- Backup
- Import/export
- Synchronisation
- Cross-device support

without implementing those capabilities now.

---

## 51. Workspace Readiness

V1 may have only one workspace.

However, data structures should avoid making multiple workspaces impossible later.

Prefer:

```text
workspace_id
```

on relevant entities.

Do **not** build multi-workspace UI in V1.

---

## 52. Database Migrations

Every schema change must use an explicit migration.

Never modify an existing production schema destructively.

Maintain:

```text
schema_version
```

and migration history.

The application must support upgrading from previous versions.

---

## 53. Network Policy

Core WorkPulse functionality requires no network.

V1 should make:

```text
No outbound network requests
```

The architecture may support optional future features such as:

- Jira integration
- Cloud backup
- Sync
- AI services
- Remote dashboard

but these must be:

- Explicitly enabled
- Separate from core functionality
- Disabled by default
- Non-essential to tracking

---

## 54. Privacy / No Surveillance

WorkPulse must not implement:

- Screen recording
- Screenshots
- Keystroke logging
- Webcam monitoring
- Microphone monitoring
- Browser history collection
- Application usage monitoring
- Communication monitoring

Idle detection is limited to determining lack of detectable user input for the purpose of prompting the user.

---

## 55. Export

V1 should support:

### CSV

Include:

```text
Date
Project
Category
WorkItem
Tags
People
Session Start
Session End
Duration
Idle Duration
Active Duration
Custom Attributes
```

### JSON

Include the complete structured WorkPulse data needed to reconstruct the records.

---

## 56. Backup / Restore

Full backup/restore is **not required in V1**.

However, the architecture must not prevent it later.

Stable IDs and versioned schema are mandatory foundations.

---

## 57. Import

Import is not required in V1.

Future import could support:

- CSV
- JSON
- Migration from other time-tracking applications

---

## 58. Future Profiles

Future versions may support workflow profiles.

Example:

### Engineering

```text
Project
Category
Jira ID
Environment
People
Tags
```

### Consulting

```text
Client
Engagement
Work Type
People
Reference
```

### Leadership

```text
Project
Category
Meeting Type
People
```

Do not implement profiles in V1.

---

## 59. Platform Architecture

Shared Flutter application:

```text
                 Flutter Application
                         │
             ┌───────────┴───────────┐
             │                       │
          macOS                   Windows
             │                       │
      Native services          Native services
```

Platform-specific:

- Global shortcut
- Menu/system tray
- Window management
- Notifications
- Startup
- Idle detection

Shared:

- Domain
- UI
- SQLite
- State management
- Timer logic
- Sessions
- Reporting
- Search
- Export

---

## 60. Project Structure

```text
workpulse/
│
├── README.md
├── LICENSE
│
├── docs/
│   ├── WORKPULSE_SPEC.md
│   ├── DESIGN.md
│   └── DEVELOPMENT.md
│
├── lib/
│   ├── core/
│   │   ├── database/
│   │   ├── errors/
│   │   ├── theme/
│   │   ├── utils/
│   │   └── platform/
│   │
│   ├── domain/
│   │   ├── models/
│   │   ├── repositories/
│   │   └── services/
│   │
│   ├── data/
│   │   ├── database/
│   │   ├── migrations/
│   │   └── repositories/
│   │
│   ├── features/
│   │   ├── quick_capture/
│   │   ├── work_items/
│   │   ├── sessions/
│   │   ├── projects/
│   │   ├── categories/
│   │   ├── tags/
│   │   ├── people/
│   │   ├── attributes/
│   │   ├── dashboard/
│   │   ├── reports/
│   │   └── settings/
│   │
│   └── main.dart
│
└── test/
```

---

## 61. State Management

Use Riverpod.

Timer state must have a single authoritative source.

Suggested states:

```text
NoActiveSession
StartingSession
SessionActive
SwitchConfirmation
StoppingSession
IdleDetected
ResolvingIdle
```

---

## 62. Timer State Machine

```text
                 ┌──────────────┐
                 │              │
                 ▼              │
             ┌───────┐         │
             │  NONE │         │
             └───┬───┘         │
                 │ Start       │
                 ▼             │
             ┌────────┐        │
             │ ACTIVE │────────┘
             └───┬────┘
                 │
         inactivity detected
                 │
                 ▼
          ┌─────────────┐
          │ IDLE PROMPT │
          └──────┬──────┘
            ┌────┼─────┐
            │    │     │
            ▼    ▼     ▼
          Keep  Idle  Stop
            │    │     │
            └─┬──┘     ▼
              │       NONE
              ▼
            ACTIVE
```

---

## 63. Quick Capture State Machine

```text
Closed
   │
   │ Shortcut
   ▼
Opened
   │
   ├── Search existing
   │       │
   │       └── Select
   │
   └── Create new
           │
           ▼
       WorkItem name
           │
           ▼
        Project
           │
           ▼
        Category
           │
           ▼
     Configured metadata
           │
           ▼
          Start
           │
           ▼
         Closed
```

---

## 64. Keyboard UX

Primary controls:

```text
Option + Space
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
Navigate results
```

Shortcut configuration should be supported.

---

## 65. Performance

Quick Capture target:

> **<300 ms perceived response time** under normal conditions.

Local search should feel instantaneous for a normal personal dataset.

Avoid loading the entire database into memory.

Background CPU usage should be minimal when no active session is running.

---

## 66. Testing

### Unit tests

Cover:

- Session duration
- Task switching
- Resume
- Idle handling
- Sleep/wake
- Midnight crossing
- Timezone behaviour
- Reporting
- Aggregation
- Attribute validation
- Search

### Repository tests

Cover:

- CRUD
- Relationships
- Session lifecycle
- Attribute lifecycle
- Archiving

### Widget tests

Cover:

- Quick Capture
- New WorkItem
- Search
- Keyboard navigation
- Switch confirmation
- Idle prompt
- Configurable attributes

### Integration test

```text
Create WorkItem
→ Start
→ Stop
→ Resume
→ Stop
→ Report
```

Also test task-switch cancel and confirmed switching.

---

## 67. AI Coding Agent Rules

The AI coding agent must:

1. Implement incrementally.
2. Complete one vertical slice before starting the next.
3. Never implement future functionality without explicit instruction.
4. Keep domain logic independent from widgets.
5. Keep database access behind repositories.
6. Isolate platform-specific code.
7. Use database migrations.
8. Use stable UUIDs.
9. Write tests alongside business logic.
10. Never silently modify historical time.
11. Never silently discard idle periods.
12. Never allow multiple active sessions.
13. Keep Quick Capture keyboard-first.
14. Avoid unnecessary abstractions.
15. Maintain Apple Silicon compatibility.
16. Preserve the Windows migration path.
17. Document significant architectural decisions.
18. Do not hardcode organisation-specific fields.
19. Do not introduce network dependencies into core functionality.

---

## 68. V1 Development Sequence

### Phase 1 — Foundation

- Flutter project
- Riverpod
- SQLite
- Migrations
- Domain models
- Repository architecture

### Phase 2 — Work Management

- WorkItems
- Projects
- Categories
- Tags
- People
- Search

### Phase 3 — Tracking

- Sessions
- Start
- Stop
- Resume
- One active session
- Timestamp-based duration

### Phase 4 — Quick Capture

- Floating window
- Global shortcut
- Keyboard navigation
- New WorkItem
- Existing WorkItem search

### Phase 5 — Switching

- Task switching
- Confirmation
- Session transition

### Phase 6 — Configurable Attributes

- Attribute definitions
- Attribute types
- Options
- Validation
- Quick Capture visibility
- Searchability
- Reporting metadata

### Phase 7 — Idle

- Activity detection
- Idle prompt
- Idle resolution
- Sleep/wake handling

### Phase 8 — macOS Integration

- Menu bar
- Notifications
- Startup
- Window management
- Global shortcut

### Phase 9 — Dashboard

- Today
- Week
- Custom range
- Project
- Category
- WorkItem
- People
- Tags

### Phase 10 — Export & Hardening

- CSV
- JSON
- Historical editing
- Recovery
- Performance
- Migration testing
- Packaging

---

## 69. Explicit V1 Non-Goals

Do not implement:

- Cloud sync
- Accounts
- Authentication
- Cloud database
- Cloud dependency
- Web dashboard
- Localhost server
- Jira API
- Azure DevOps integration
- ServiceNow integration
- Calendar integration
- Slack integration
- Teams integration
- AI-generated summaries
- Automatic task classification
- Automatic application categorisation
- Screen monitoring
- Screenshots
- Keystroke logging
- Browser monitoring
- Windows support
- Multi-workspace UI
- Workflow profiles
- Backup/restore UI

The architecture should allow these later.

---

## 70. V1 Definition of Done

A user can:

1. Install WorkPulse on macOS.
2. Launch it as a menu-bar utility.
3. Invoke Quick Capture from any application.
4. Create a WorkItem.
5. Select a Project.
6. Select a Category.
7. Add configured metadata.
8. Start tracking.
9. Return immediately to their previous application.
10. Reopen Quick Capture.
11. Search existing WorkItems.
12. Select another WorkItem.
13. Receive a switch confirmation.
14. Confirm or cancel.
15. Stop without a mandatory follow-up.
16. Resume the WorkItem later.
17. See each session separately.
18. Detect inactivity.
19. Resolve idle periods explicitly.
20. Recover after application restart.
21. Handle Mac sleep/wake.
22. View daily and weekly reports.
23. Search historical work.
24. Edit historical sessions.
25. Archive old WorkItems/projects/categories.
26. Configure custom attributes.
27. Search and report using configured attributes.
28. Export their data.
29. Use core functionality without internet access.

---

## 71. Critical Architectural Rules

### Rule 1

**Jira must not appear anywhere in the core domain model.**

### Rule 2

**Organisation-specific metadata must be configurable.**

### Rule 3

**Quick Capture must remain fast even when the metadata model becomes complex.**

### Rule 4

**One and only one session may be active.**

### Rule 5

**Raw session timestamps are the source of truth.**

### Rule 6

**Historical data must never be silently destroyed by configuration changes.**

### Rule 7

**Stopping a session does not complete the WorkItem.**

### Rule 8

**Core functionality must not depend on network connectivity.**

### Rule 9

**Platform-specific code must be isolated behind interfaces.**

### Rule 10

**The database must be migration-based and use stable IDs.**

---

## 72. Target Architecture

```text
                         WorkPulse
                            │
              ┌─────────────┴─────────────┐
              │                           │
        Work Management              Time Tracking
              │                           │
       ┌──────┼───────┐             ┌─────┴─────┐
       │      │       │             │           │
    Project Category WorkItem     Session      Idle
                     │
          ┌──────────┼──────────────┐
          │          │              │
        Tags       People       Attributes
                                   │
                          User-defined schema
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
                  Text          Select        Multi-select
```

---

## 73. Product Definition

WorkPulse is not merely a local Toggl replacement.

> **WorkPulse is a local-first work-awareness system where time sessions are attached to work items and the context surrounding those work items can be configured to match the user's workflow.**

The timer is one dimension of the work record, not the entire product.
