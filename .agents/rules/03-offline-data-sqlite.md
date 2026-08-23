# Rule: Offline Data Integrity & SQLite Schema

WorkPulse stores 100% of its data locally in SQLite (`sqflite_common_ffi`). Data integrity across crashes, sleep/wake, and background execution is paramount.

## Core Data Rules:

1. **Timestamp-Based Math**:
   - Store all timestamps in ISO-8601 UTC strings (`DateTime.toUtc().toIso8601String()`).
   - Durations MUST be computed as `end_time - start_time` wall-clock difference.
   - For currently running sessions: `elapsed = DateTime.now().toUtc() - session.startTime.toUtc()`.
   - Never increment an in-memory integer counter as the primary record of time.

2. **Active Session Recovery on Startup**:
   - On application launch, query SQLite for any `session` where `end_time IS NULL`.
   - If an unfinished session exists:
     - Automatically resume tracking.
     - Calculate elapsed time based on `start_time` vs current wall-clock time.
     - Update Menu Bar status and global timer state.

3. **Database Schema & Migrations**:
   - Follow strict schema migrations with version increments (`PRAGMA user_version`).
   - Tables (16 total):
     - `workspaces (id TEXT PRIMARY KEY, name TEXT UNIQUE, created_at TEXT, updated_at TEXT)`
     - `projects (id TEXT PRIMARY KEY, workspace_id TEXT, name TEXT, description TEXT, color_hex TEXT, created_at TEXT, updated_at TEXT, archived_at TEXT)`
     - `categories (id TEXT PRIMARY KEY, workspace_id TEXT, name TEXT, description TEXT, icon_name TEXT, created_at TEXT, updated_at TEXT, archived_at TEXT)`
     - `tags (id TEXT PRIMARY KEY, workspace_id TEXT, name TEXT, color_hex TEXT, created_at TEXT)`
     - `people (id TEXT PRIMARY KEY, workspace_id TEXT, name TEXT, email TEXT, created_at TEXT)`
     - `work_items (id TEXT PRIMARY KEY, workspace_id TEXT, name TEXT, project_id TEXT, category_id TEXT, notes TEXT, created_at TEXT, updated_at TEXT, last_worked_at TEXT, archived_at TEXT)`
     - `work_item_tags (work_item_id TEXT, tag_id TEXT, PRIMARY KEY (work_item_id, tag_id))`
     - `work_item_people (work_item_id TEXT, person_id TEXT, PRIMARY KEY (work_item_id, person_id))`
     - `sessions (id TEXT PRIMARY KEY, work_item_id TEXT, start_time TEXT NOT NULL, end_time TEXT, created_at TEXT)`
     - `session_people (session_id TEXT, person_id TEXT, PRIMARY KEY (session_id, person_id))`
     - `idle_periods (id TEXT PRIMARY KEY, session_id TEXT, start_time TEXT NOT NULL, end_time TEXT NOT NULL, resolution TEXT NOT NULL, created_at TEXT NOT NULL)`
     - `attribute_definitions (id TEXT PRIMARY KEY, workspace_id TEXT, key TEXT, name TEXT, description TEXT, type TEXT, scope TEXT, required INTEGER, enabled INTEGER, searchable INTEGER, reportable INTEGER, show_in_quick_capture INTEGER, show_in_task_details INTEGER, display_order INTEGER, created_at TEXT, updated_at TEXT, archived_at TEXT)`
     - `attribute_options (id TEXT PRIMARY KEY, attribute_definition_id TEXT, value TEXT, label TEXT, color_hex TEXT, display_order INTEGER, is_default INTEGER, created_at TEXT, archived_at TEXT)`
     - `work_item_attribute_values (id TEXT PRIMARY KEY, work_item_id TEXT, attribute_definition_id TEXT, text_value TEXT, number_value REAL, boolean_value INTEGER, date_value TEXT, option_id TEXT, created_at TEXT, updated_at TEXT)`
     - `session_attribute_values (id TEXT PRIMARY KEY, session_id TEXT, attribute_definition_id TEXT, text_value TEXT, number_value REAL, boolean_value INTEGER, date_value TEXT, option_id TEXT, created_at TEXT, updated_at TEXT)`
     - `settings (key TEXT PRIMARY KEY, value TEXT)`

4. **Multi-Select Attribute Value Normalization**:
   - For attributes of type `multi_select`, persist **one row per selected option** in `work_item_attribute_values` / `session_attribute_values` sharing the same `work_item_id` / `session_id` and `attribute_definition_id`, with each row pointing to a distinct `option_id`.
   - Never serialize selected IDs into comma-separated text strings.

5. **Soft-Archiving & Deletion Invariants**:
   - Deleting projects, categories, work items, or attribute definitions must set `archived_at` timestamp.
   - Historical sessions must never be cascade-deleted when modifying configuration entities.

6. **Foreign Keys & Indices**:
   - Always enable `PRAGMA foreign_keys = ON;` upon opening the database.
   - Maintain indices on foreign keys, search fields, and timestamp query bounds.
