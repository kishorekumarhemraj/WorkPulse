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

### Project
```text
Project
├── id: UUID (String)
├── workspaceId: UUID (String, Required)
├── name: String (Required)
├── description: String? (Optional)
├── colorHex: String? (Optional, e.g. "#4F46E5")
├── createdAt: DateTime (UTC)
├── updatedAt: DateTime (UTC)
└── archivedAt: DateTime? (UTC)
```

### Category
```text
Category
├── id: UUID (String)
├── workspaceId: UUID (String, Required)
├── name: String (Required)
├── description: String? (Optional)
├── iconName: String? (Optional, e.g. "code", "chat")
├── createdAt: DateTime (UTC)
├── updatedAt: DateTime (UTC)
└── archivedAt: DateTime? (UTC)
```

### Tag
```text
Tag
├── id: UUID (String)
├── workspaceId: UUID (String, Required)
├── name: String (Required)
├── colorHex: String? (Optional)
└── createdAt: DateTime (UTC)
```

### Person
```text
Person
├── id: UUID (String)
├── workspaceId: UUID (String, Required)
├── name: String (Required)
├── email: String? (Optional)
└── createdAt: DateTime (UTC)
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

### Session
```text
Session
├── id: UUID (String)
├── workItemId: UUID (String, Required)
├── startTime: DateTime (UTC, Required)
├── endTime: DateTime? (UTC, null if currently active)
├── peopleIds: List<String> (Session-specific participants)
└── createdAt: DateTime (UTC)
```
*Note: Total work item duration is the sum of all completed session durations for that work item (`endTime - startTime`) plus the active session elapsed time if running.*

### IdlePeriod
```text
IdlePeriod
├── id: UUID (String)
├── sessionId: UUID (String, Required)
├── startTime: DateTime (UTC, Required)
├── endTime: DateTime (UTC, Required)
├── resolution: IdleResolution (keep_tracking, mark_idle, stop_session)
└── createdAt: DateTime (UTC)
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
├── createdAt: DateTime (UTC)
├── updatedAt: DateTime (UTC)
└── archivedAt: DateTime? (UTC)

AttributeOption
├── id: UUID (String)
├── attributeDefinitionId: UUID (String)
├── value: String
├── label: String
├── colorHex: String?
├── displayOrder: int
├── isDefault: bool
├── createdAt: DateTime (UTC)
└── archivedAt: DateTime? (UTC)

WorkItemAttributeValue
├── id: UUID (String)
├── workItemId: UUID (String)
├── attributeDefinitionId: UUID (String)
├── textValue: String?
├── numberValue: double?
├── booleanValue: bool?
├── dateValue: DateTime?
├── optionId: UUID?
├── createdAt: DateTime (UTC)
└── updatedAt: DateTime (UTC)

SessionAttributeValue
├── id: UUID (String)
├── sessionId: UUID (String)
├── attributeDefinitionId: UUID (String)
├── textValue: String?
├── numberValue: double?
├── booleanValue: bool?
├── dateValue: DateTime?
├── optionId: UUID?
├── createdAt: DateTime (UTC)
└── updatedAt: DateTime (UTC)
```

---

## 2. Timer State Machine

```text
                     ┌──────────────────┐
                     │                  │
                     ▼                  │
             ┌───────────────┐          │
             │   STOPPED     │          │
             │ (No Session)  │          │
             └───────┬───────┘          │
                     │ Start            │
                     ▼                  │
             ┌───────────────┐          │
             │    ACTIVE     │──────────┘
             │(Tracking Task)│
             └───────┬───────┘
                     │ Inactivity detected (> threshold)
                     ▼
             ┌───────────────┐
             │  IDLE PROMPT  │
             └───────┬───────┘
            ┌────────┼────────┐
            │        │        │
            ▼        ▼        ▼
       [Keep Time] [Mark Idle] [Stop Session]
            │        │        │
            │        ▼        ▼
            │   (Record Idle) └──> STOPPED
            │        │
            └────────┴───> ACTIVE
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

---

## 4. Multi-Select Attribute Storage Standard

For attributes with `type == AttributeType.multiSelect`:
- Values are stored normalized as **one row per selected option** in `work_item_attribute_values` (or `session_attribute_values`).
- Each row contains:
  - `work_item_id` (or `session_id`)
  - `attribute_definition_id`
  - `option_id` (pointing to the selected `AttributeOption`)
- Reading multi-select values retrieves all rows matching `(work_item_id, attribute_definition_id)`.

---

## 5. Day-Boundary Allocation for Reports

When a session spans across UTC midnight (e.g. `23:45 UTC` to `01:15 UTC` next day):
1. **Raw Storage:** `sessions` table retains exact timestamps (`startTime = 23:45`, `endTime = 01:15`).
2. **Reporting Aggregation:** The reporting engine splits the duration into date buckets:
   - Day 1: 15 minutes (`23:45` to `24:00`)
   - Day 2: 75 minutes (`00:00` to `01:15`)
3. **Net Active Time:** Idle periods within the session are subtracted from their respective day buckets based on the idle period's timestamps.
