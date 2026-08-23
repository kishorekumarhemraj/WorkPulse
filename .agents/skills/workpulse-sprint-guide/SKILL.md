---
name: workpulse-sprint-guide
description: 10-Sprint vertical slice development roadmap for implementing WorkPulse incrementally with automated verification.
---

# WorkPulse 10-Sprint Vertical Slice Implementation Guide

WorkPulse must be developed in vertical slices (not all at once) as specified in PRD Section 48.

## Sprint Roadmap

### 🏁 Sprint 1 — Project Foundation & Persistence
- **Deliverable**: App launches, initializes SQLite database with foreign keys, executes migrations, and persists basic records.
- **Components**:
  - `lib/core/database/database_helper.dart` (SQLite connection, `PRAGMA foreign_keys = ON`)
  - `lib/data/migrations/` (Initial schema migration)
  - `lib/domain/models/` (Core entities: Task, Session, Project, Category)
- **Verification**: Unit tests for SQLite DB connection and schema table verification.

---

### 📋 Sprint 2 — Projects, Categories & Tasks CRUD
- **Deliverable**: User can create, edit, list, and search projects, categories, and tasks.
- **Components**:
  - `lib/domain/repositories/task_repository.dart`, `project_repository.dart`, `category_repository.dart`
  - `lib/data/repositories/` (SQLite implementations with indexed queries)
  - Task search with case-insensitive filtering.
- **Verification**: Unit & repository tests covering full CRUD and search query matching.

---

### ⏱️ Sprint 3 — Core Timer & Session Engine
- **Deliverable**: Start, stop, and resume task timers. Enforce single-active-task invariant.
- **Components**:
  - `lib/domain/services/timer_service.dart`
  - `lib/features/timer/providers/timer_provider.dart`
  - Wall-clock timestamp math (`elapsed = now - startTime`).
  - Active session crash/sleep recovery on app startup.
- **Verification**: Tests for session start/stop, multi-session task resume, duration calculation across simulated time gaps.

---

### ⚡ Sprint 4 — Quick Capture Floating UI
- **Deliverable**: Global keyboard shortcut opens lightweight popup (<300ms) with keyboard navigation.
- **Components**:
  - `lib/features/quick_capture/` (Floating search & creation dialog)
  - Keyboard listeners (`Escape` to close, `Enter` to submit, `Tab` cycling)
- **Verification**: Widget tests testing keyboard actions and UI states.

---

### 🔄 Sprint 5 — Task Switching
- **Deliverable**: Seamlessly transition from active Task A to Task B.
- **Components**:
  - Task switcher controller stopping Session A and starting Session B atomically.
- **Verification**: Integration test for task switch state transitions.

---

### 🏷️ Sprint 6 — Metadata (Tags, People, Jira)
- **Deliverable**: Attach tags, team members, and Jira keys to tasks and sessions.
- **Components**:
  - `task_tags`, `task_people`, `session_people` junction table repositories.
  - Autocomplete selectors in Quick Capture.
- **Verification**: Tests for tag & person relationship persistence and filtering.

---

### 💤 Sprint 7 — Idle Detection & Prompt
- **Deliverable**: Detect inactivity and prompt user to Keep Tracking, Mark Idle, or Stop Session.
- **Components**:
  - Inactivity detector service & `idle_periods` table logging.
- **Verification**: Unit test covering idle resolution states.

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
  - Aggregation queries for time-by-project, category, person, and deep-work ratio.
- **Verification**: Tests for aggregation correctness with multiple multi-day sessions.

---

### 📤 Sprint 10 — Reports & Local Export
- **Deliverable**: Export tracked sessions to CSV and JSON formats locally.
- **Components**:
  - `lib/features/reports/services/export_service.dart` (CSV & JSON generator).
- **Verification**: Automated test verifying CSV column layout and export data accuracy.
