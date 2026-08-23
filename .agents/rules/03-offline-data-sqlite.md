# Rule: Offline Data Integrity & SQLite Schema

WorkPulse stores 100% of its data locally in SQLite. Data integrity across crashes, sleep/wake, and background execution is paramount.

## Core Data Rules:
1. **Timestamp-Based Math**:
   - Store all timestamps in ISO-8601 UTC strings or UTC epoch milliseconds.
   - Durations MUST be computed as `end_time - start_time` wall-clock difference.
   - For currently running sessions, `elapsed = DateTime.now().toUtc() - session.startTime.toUtc()`.
   - Never increment a counter integer in memory as the primary record of time.
2. **Active Session Recovery on Startup**:
   - On application launch, query SQLite for any `session` where `end_time IS NULL`.
   - If an unfinished session exists:
     - Automatically resume tracking.
     - Calculate elapsed time based on `start_time` vs current wall-clock time.
     - Update Menu Bar status.
3. **Database Schema & Migrations**:
   - Follow strict schema migrations with version increments (`PRAGMA user_version`).
   - Tables:
     - `projects (id TEXT PRIMARY KEY, name TEXT UNIQUE, color TEXT, created_at TEXT)`
     - `categories (id TEXT PRIMARY KEY, name TEXT UNIQUE, icon TEXT, created_at TEXT)`
     - `tags (id TEXT PRIMARY KEY, name TEXT UNIQUE, created_at TEXT)`
     - `people (id TEXT PRIMARY KEY, name TEXT UNIQUE, created_at TEXT)`
     - `tasks (id TEXT PRIMARY KEY, name TEXT, project_id TEXT, category_id TEXT, jira_id TEXT, notes TEXT, created_at TEXT, updated_at TEXT)`
     - `task_tags (task_id TEXT, tag_id TEXT, PRIMARY KEY (task_id, tag_id))`
     - `task_people (task_id TEXT, person_id TEXT, PRIMARY KEY (task_id, person_id))`
     - `sessions (id TEXT PRIMARY KEY, task_id TEXT, start_time TEXT NOT NULL, end_time TEXT, created_at TEXT)`
     - `session_people (session_id TEXT, person_id TEXT, PRIMARY KEY (session_id, person_id))`
     - `idle_periods (id TEXT PRIMARY KEY, session_id TEXT, start_time TEXT, end_time TEXT, resolution TEXT)`
     - `settings (key TEXT PRIMARY KEY, value TEXT)`
4. **Foreign Keys & Indices**:
   - Always enable `PRAGMA foreign_keys = ON;`.
   - Create indices on `sessions(task_id)`, `sessions(start_time)`, `tasks(name)`, and `tasks(project_id)`.
