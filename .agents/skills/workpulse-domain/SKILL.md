---
name: workpulse-domain
description: Deep reference for WorkPulse domain models, entity relationships, and state machines (Timer, Quick Capture, Task Switching, Idle Detection, Configurable Attributes).
---

# WorkPulse Domain Reference & State Machines

This skill provides the authoritative specifications for the WorkPulse domain layer, business rules, and state machine flows.

## 1. Domain Entities & Relationships

### Workspace
```text
Workspace
├── id: UUID (String)
├── name: String (Required, default: "Default")
├── createdAt: DateTime (UTC)
└── updatedAt: DateTime (UTC)
```

### WorkItem
```text
WorkItem
├── id: UUID (String)
├── workspaceId: UUID (String, Required)
├── name: String (Required)
├── projectId: UUID (String, Required)
├── categoryId: UUID (String, Required)
├── notes: String? (Optional)
├── tagIds: List<String> (Optional)
├── peopleIds: List<String> (Optional)
├── createdAt: DateTime (UTC)
├── updatedAt: DateTime (UTC)
├── lastWorkedAt: DateTime? (UTC)
└── archivedAt: DateTime? (UTC)
```

### Configurable Attributes
```text
AttributeDefinition
├── id: UUID (String)
├── workspaceId: UUID (String)
├── key: String (Stable internal identifier, e.g. "jira_id", "cost_centre")
├── name: String (Display label, e.g. "Jira ID", "Cost Centre")
├── description: String?
├── type: AttributeType (text, number, boolean, singleSelect, multiSelect, date)
├── scope: AttributeScope (task, session)
├── required: bool
├── enabled: bool
├── searchable: bool
├── reportable: bool
├── showInQuickCapture: bool
├── showInTaskDetails: bool
├── displayOrder: int
├── createdAt: DateTime
├── updatedAt: DateTime
└── archivedAt: DateTime?

AttributeOption
├── id: UUID (String)
├── attributeDefinitionId: UUID (String)
├── value: String
├── label: String
├── colorHex: String?
├── displayOrder: int
├── isDefault: bool
├── createdAt: DateTime
└── archivedAt: DateTime?

WorkItemAttributeValue
├── id: UUID (String)
├── workItemId: UUID (String)
├── attributeDefinitionId: UUID (String)
├── textValue: String?
├── numberValue: double?
├── booleanValue: bool?
├── dateValue: DateTime?
├── optionId: UUID?
├── createdAt: DateTime
└── updatedAt: DateTime
```

### Session
```text
Session
├── id: UUID (String)
├── workItemId: UUID (String)
├── startTime: DateTime (UTC)
├── endTime: DateTime? (UTC, null if currently active)
├── peopleIds: List<String> (Session-specific participants)
└── createdAt: DateTime (UTC)
```

*Note: Total work item duration is the sum of all completed session durations for that work item (`endTime - startTime`) plus the active session elapsed time if running.*

### Project & Category
- **Project**: User workspace grouping (e.g. "WorkPulse Core", "Personal"). Contains `workspaceId`.
- **Category**: Functional classification (e.g. "Engineering", "Architecture", "Meetings", "Deep Work"). Contains `workspaceId`.

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

### WorkItem Switching Flow
1. User triggers work item selection when WorkItem A is currently `ACTIVE`.
2. App checks if target work item is WorkItem A (no-op) or WorkItem B.
3. If WorkItem B: Show switch confirmation dialog.
4. If confirmed: Stop Session A (set `endTime = DateTime.now().toUtc()`).
5. Persist Session A to SQLite.
6. Create Session B for WorkItem B (`startTime = DateTime.now().toUtc()`).
7. Update Menu Bar and Timer state to WorkItem B.

---

## 3. Quick Capture Workflow

```text
Closed
  │
  │ Global Shortcut (⌥ + Space)
  ▼
Opened (Focus on WorkItem Name / Search input)
  │
  ├── Search Existing WorkItems
  │        │
  │        └── Select / Arrow keys + Enter ──> Switch / Resume WorkItem
  │
  └── Create New WorkItem
           │
           ├── Enter WorkItem Name (Enter or Tab)
           ├── Select Project (Autocompletes)
           ├── Select Category (Autocompletes)
           ├── (Optional) Configured Attributes, Tags, People
           └── Press Enter / Cmd+Enter ──> Start Session & Close Popup (<300ms)
```
