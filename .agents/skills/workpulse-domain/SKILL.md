---
name: workpulse-domain
description: Deep reference for WorkPulse domain models, entity relationships, and state machines (Timer, Quick Capture, Task Switching, Idle Detection).
---

# WorkPulse Domain Reference & State Machines

This skill provides the authoritative specifications for the WorkPulse domain layer, business rules, and state machine flows.

## 1. Domain Entities & Relationships

### Task
```text
Task
├── id: UUID (String)
├── name: String (Required)
├── projectId: UUID (String, Required)
├── categoryId: UUID (String, Required)
├── tagIds: List<String> (Optional)
├── peopleIds: List<String> (Optional)
├── jiraId: String? (Optional, e.g. "PLAT-1234")
├── notes: String? (Optional)
├── createdAt: DateTime
└── updatedAt: DateTime
```

### Session
```text
Session
├── id: UUID (String)
├── taskId: UUID (String)
├── startTime: DateTime (UTC)
├── endTime: DateTime? (UTC, null if currently active)
├── peopleIds: List<String> (Session-specific participants)
└── createdAt: DateTime
```

*Note: Total task duration is the sum of all completed session durations for that task (`endTime - startTime`) plus the active session elapsed time if running.*

### Project & Category
- **Project**: User workspace grouping (e.g. "OpenText Platform", "Personal").
- **Category**: Functional classification (e.g. "Engineering", "Architecture", "Meetings", "Deep Work").

---

## 2. Timer State Machine

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
                     │ Inactivity detected
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

### Task Switching Flow
1. User triggers task selection when Task A is currently `ACTIVE`.
2. App checks if target task is Task A (no-op) or Task B.
3. If Task B: Show prompt / quick confirmation if needed or immediate switch.
4. Stop Session A (set `endTime = DateTime.now().toUtc()`).
5. Persist Session A to SQLite.
6. Create Session B for Task B (`startTime = DateTime.now().toUtc()`).
7. Update Menu Bar and Timer state to Task B.

---

## 3. Quick Capture Workflow

```text
Closed
  │
  │ Global Shortcut (⌥ + Space)
  ▼
Opened (Focus on Task Name / Search input)
  │
  ├── Search Existing Task
  │        │
  │        └── Select / Arrow keys + Enter ──> Switch / Resume Task
  │
  └── Create New Task
           │
           ├── Enter Task Name (Enter or Tab)
           ├── Select Project (Autocompletes)
           ├── Select Category (Autocompletes)
           ├── (Optional) Tags, People, Jira ID
           └── Press Enter / Cmd+Enter ──> Start Session & Close Popup
```
