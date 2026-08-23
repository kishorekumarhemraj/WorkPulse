---
name: workpulse-sprint-guide
description: 10-Sprint vertical slice development roadmap for implementing WorkPulse incrementally with automated verification.
---

# WorkPulse 10-Sprint Vertical Slice Implementation Guide

WorkPulse is developed in vertical slices following `docs/WORKPULSE_SPEC.md` Section 68.

## Sprint Roadmap & Current Status

| Sprint | Description | Status | Verification Command |
| :--- | :--- | :--- | :--- |
| **Sprint 1** | Foundation & SQLite Schema (16 tables, migrations) | ✅ Complete | `flutter test test/data/database_migration_test.dart` |
| **Sprint 2** | Work Management (Projects, Categories, WorkItems, Tags, People) | ✅ Complete | `flutter test test/data/sqlite_repositories_test.dart` |
| **Sprint 3** | Core Timer & Single Active Session Engine | ✅ Complete | `flutter test test/unit/services/timer_service_test.dart` |
| **Sprint 4** | Quick Capture Floating UI & Keyboard Navigation | ✅ Complete | `flutter test test/widget/quick_capture_ui_test.dart` |
| **Sprint 5** | Task Switching & Confirmation State Machine | ✅ Complete | `flutter test test/integration/task_switching_integration_test.dart` |
| **Sprint 6** | Configurable Attributes & Dynamic Forms | ✅ Complete | `flutter test test/unit/providers/attributes_provider_test.dart` |
| **Sprint 7** | Inactivity Detection, Idle Prompt & Resolution | ✅ Complete | `flutter test test/unit/services/idle_service_test.dart` |
| **Sprint 8** | macOS Menu Bar Tray, Window Manager & Global Hotkey | 🔄 Next | `flutter test test/widget/timer_ui_test.dart` |
| **Sprint 9** | Dashboard, Analytics & Reporting Aggregations | ⏳ Pending | `flutter test test/unit/` |
| **Sprint 10** | CSV/JSON Export, Historical Session Editing & Hardening | ⏳ Pending | `flutter test test/` |

---

## Detailed Sprint Specifications

### 🏁 Sprint 1 — Project Foundation & Persistence
- **Deliverable**: App initializes SQLite database with foreign keys enabled (`PRAGMA foreign_keys = ON`), executes migration V1 (16 tables), and enforces schema constraints.
- **Components**:
  - `lib/core/database/database_service.dart`
  - `lib/data/migrations/migration_v1.dart`
  - `lib/data/database/tables.dart`
  - `lib/domain/models/` and `lib/domain/repositories/`
- **Verification**: `flutter test test/data/database_migration_test.dart`

---

### 📋 Sprint 2 — Work Management
- **Deliverable**: CRUD and search operations for Projects, Categories, WorkItems, Tags, and People.
- **Components**:
  - `lib/data/repositories/sqlite_work_item_repository.dart`
  - `lib/data/repositories/sqlite_project_repository.dart`
  - `lib/data/repositories/sqlite_category_repository.dart`
  - `lib/data/repositories/sqlite_tag_repository.dart`
  - `lib/data/repositories/sqlite_person_repository.dart`
  - `lib/features/tasks/`, `projects/`, `categories/`, `tags/`, `people/`
- **Verification**: `flutter test test/data/sqlite_repositories_test.dart`

---

### ⏱️ Sprint 3 — Core Timer & Session Engine
- **Deliverable**: Start, stop, and resume work item timers. Enforce single-active-session invariant. Compute elapsed duration via wall-clock timestamps (`now - start_time`).
- **Components**:
  - `lib/domain/services/timer_service.dart`
  - `lib/features/timer/providers/timer_provider.dart`
  - Startup recovery for unclosed sessions (`end_time IS NULL`).
- **Verification**: `flutter test test/unit/services/timer_service_test.dart`

---

### ⚡ Sprint 4 — Quick Capture Floating UI
- **Deliverable**: Global shortcut (`⌥ + Space`) opens lightweight popup (<300ms) with keyboard-first navigation (`Enter` to start/switch, `Esc` to cancel, `Tab`/`Shift+Tab` cycling, `Arrow` keys for search).
- **Components**:
  - `lib/features/quick_capture/views/quick_capture_dialog.dart`
  - `lib/features/quick_capture/providers/quick_capture_provider.dart`
- **Verification**: `flutter test test/widget/quick_capture_ui_test.dart`

---

### 🔄 Sprint 5 — Task Switching
- **Deliverable**: Seamless transition from active WorkItem A to WorkItem B with confirmation dialog, cleanly closing Session A before opening Session B.
- **Components**:
  - `lib/domain/services/task_switch_service.dart`
  - `lib/features/timer/views/task_switch_dialog.dart`
- **Verification**: `flutter test test/integration/task_switching_integration_test.dart`

---

### 🏷️ Sprint 6 — Configurable Attributes
- **Deliverable**: Custom metadata definitions (Text, Number, Boolean, Single Select, Multi Select, Date) with Task/Session scopes, option values, Quick Capture visibility, and searchability.
- **Components**:
  - `lib/features/attributes/` (Definitions view, options editor, dynamic form fields)
  - `work_item_attribute_values` and `session_attribute_values` normalized persistence.
- **Verification**: `flutter test test/widget/attributes_ui_test.dart`

---

### 💤 Sprint 7 — Idle Detection & Prompt
- **Deliverable**: Detect user inactivity and prompt user to Keep Tracking, Mark Idle, or Stop Session.
- **Components**:
  - `lib/core/platform/idle_detector_service.dart`
  - `lib/domain/services/idle_service.dart`
  - `lib/features/idle/views/idle_prompt_dialog.dart`
- **Verification**: `flutter test test/unit/services/idle_service_test.dart test/widget/idle_ui_test.dart`

---

### 🍎 Sprint 8 — macOS Native Integration
- **Deliverable**: Menu bar extra (live ticker `⏱ 01:23:42`), dropdown menu, hotkey registration daemon, and multi-window management.
- **Components**:
  - `lib/core/platform/tray_service.dart` (`tray_manager`)
  - `lib/core/platform/hotkey_service.dart` (`hotkey_manager`)
  - `lib/core/platform/window_service.dart` (`window_manager`, `screen_retriever`)
- **Key Invariants**:
  - Tray title updates on 1-second ticks during active sessions without blocking main thread.
  - Quick Capture opens centered on the active display monitor.
  - Headless/test environments use `MockHotKeyService` and `MockTrayService`.

---

### 📊 Sprint 9 — Dashboard & Analytics
- **Deliverable**: Today, This Week, and Custom Range analytics dashboard with grouping by Project, Category, WorkItem, Person, Tag, and Configurable Attributes.
- **Components**:
  - `lib/features/dashboard/` (Dashboard view, summary metrics cards, breakdown charts)
  - `lib/features/reports/` (Aggregation queries, date range pickers, attribute breakdown)
- **Key Invariants**:
  - Net active time = Gross tracked time minus Idle periods.
  - Sessions spanning midnight are split across calendar day boundaries.

---

### 📤 Sprint 10 — Export & Hardening
- **Deliverable**: Local CSV and JSON export, historical session editing, and crash recovery hardening.
- **Components**:
  - `lib/features/reports/services/export_service.dart` (CSV & JSON generator)
  - Historical session editing dialogs.
- **Key Invariants**:
  - CSV export columns: Date, Project, Category, WorkItem, Tags, People, Start Time, End Time, Duration, Idle Duration, Active Duration, Configured Attributes.
  - JSON export contains complete reconstructible schema.
