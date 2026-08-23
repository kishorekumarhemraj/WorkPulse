---
name: workpulse-sprint-guide
description: 10-Sprint vertical slice development roadmap for implementing WorkPulse incrementally with automated verification.
---

# WorkPulse 10-Sprint Vertical Slice Implementation Guide

WorkPulse must be developed in vertical slices (not all at once) as specified in `docs/WORKPULSE_SPEC.md` Section 68.

## Sprint Roadmap

### 🏁 Sprint 1 — Project Foundation & Persistence
- **Deliverable**: App launches, initializes SQLite database with foreign keys, executes migrations, and persists basic records (Workspaces, Projects, Categories, Tags, People, WorkItems, Attributes, Sessions).
- **Components**:
  - `lib/core/database/database_service.dart` (SQLite connection, `PRAGMA foreign_keys = ON`)
  - `lib/data/migrations/` (Initial schema migration V1 with 16 tables)
  - `lib/domain/models/` (Core entities: Workspace, WorkItem, Session, Project, Category, Tag, Person, AttributeDefinition, AttributeOption)
  - `lib/domain/repositories/` and `lib/data/repositories/`
- **Verification**: Unit tests for SQLite DB connection, foreign keys, and schema table verification.

---

### 📋 Sprint 2 — Work Management (Projects, Categories, WorkItems, People, Tags)
- **Deliverable**: User can create, edit, list, and search projects, categories, tags, people, and work items.
- **Components**:
  - `lib/domain/repositories/work_item_repository.dart`, `project_repository.dart`, `category_repository.dart`, `tag_repository.dart`, `person_repository.dart`
  - `lib/data/repositories/` (SQLite implementations with indexed queries)
  - WorkItem search with case-insensitive filtering.
- **Verification**: Unit & repository tests covering full CRUD and search query matching.

---

### ⏱️ Sprint 3 — Core Timer & Session Engine
- **Deliverable**: Start, stop, and resume work item timers. Enforce single-active-session invariant.
- **Components**:
  - `lib/domain/services/timer_service.dart`
  - `lib/features/timer/providers/timer_provider.dart`
  - Wall-clock timestamp math (`elapsed = now - startTime`).
  - Active session crash/sleep recovery on app startup.
- **Verification**: Tests for session start/stop, multi-session work item resume, duration calculation across simulated time gaps.

---

### ⚡ Sprint 4 — Quick Capture Floating UI
- **Deliverable**: Global keyboard shortcut opens lightweight popup (<300ms) with keyboard navigation.
- **Components**:
  - `lib/features/quick_capture/` (Floating search & creation dialog)
  - Keyboard listeners (`Escape` to close, `Enter` to submit, `Tab` cycling, arrow navigation)
- **Verification**: Widget tests testing keyboard actions and UI states.

---

### 🔄 Sprint 5 — Task Switching
- **Deliverable**: Seamlessly transition from active WorkItem A to WorkItem B with confirmation.
- **Components**:
  - Task switcher controller stopping Session A and starting Session B atomically.
- **Verification**: Integration test for task switch state transitions and confirmation dialogs.

---

### 🏷️ Sprint 6 — Configurable Attributes
- **Deliverable**: Configure custom metadata definitions (Text, Number, Boolean, Single Select, Multi Select, Date) with Task/Session scopes, option values, Quick Capture visibility, and searchability.
- **Components**:
  - `lib/features/attributes/` (Attribute definitions, option management, validation, dynamic form fields)
  - `work_item_attribute_values` and `session_attribute_values` persistence.
- **Verification**: Tests for attribute definition lifecycle, soft-archiving, option ordering, and validation.

---

### 💤 Sprint 7 — Idle Detection & Prompt
- **Deliverable**: Detect inactivity and prompt user to Keep Tracking, Mark Idle, or Stop Session.
- **Components**:
  - Inactivity detector service & `idle_periods` table logging.
- **Verification**: Unit test covering idle resolution states and sleep/wake handling.

---

### 🍎 Sprint 8 — macOS Native Integration
- **Deliverable**: Menu bar extra (live ticker `⏱ 01:23:42`), dropdown menu, hotkey daemon.
- **Components**:
  - `tray_manager` integration, `hotkey_manager` registration for `⌥ + Space`.
- **Verification**: Desktop window lifecycle and tray interaction validation.

---

### 📊 Sprint 9 — Dashboard & Analytics
- **Deliverable**: Today, This Week, and custom range analytics dashboard.
- **Components**:
  - Aggregation queries for time-by-project, category, work item, person, tag, and custom attributes.
- **Verification**: Tests for aggregation correctness with multiple multi-day sessions.

---

### 📤 Sprint 10 — Export & Hardening
- **Deliverable**: Export tracked sessions to CSV and JSON formats locally; historical session editing; crash recovery hardening.
- **Components**:
  - `lib/features/reports/services/export_service.dart` (CSV & JSON generator).
- **Verification**: Automated test verifying CSV column layout, attribute serialization, and export data accuracy.
