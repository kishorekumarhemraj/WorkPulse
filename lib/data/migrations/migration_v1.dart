import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/data/database/tables.dart';

class MigrationV1 {
  static Future<void> execute(Database db) async {
    final batch = db.batch();

    // 1. Projects table
    batch.execute('''
      CREATE TABLE ${Tables.projects} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        color_hex TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        archived_at TEXT
      );
    ''');

    // 2. Categories table
    batch.execute('''
      CREATE TABLE ${Tables.categories} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        icon_name TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        archived_at TEXT
      );
    ''');

    // 3. Tags table
    batch.execute('''
      CREATE TABLE ${Tables.tags} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        color_hex TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    // 4. People table
    batch.execute('''
      CREATE TABLE ${Tables.people} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        email TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    // 5. Tasks table
    batch.execute('''
      CREATE TABLE ${Tables.tasks} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        project_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        jira_id TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_worked_at TEXT,
        FOREIGN KEY (project_id) REFERENCES ${Tables.projects}(id) ON DELETE RESTRICT,
        FOREIGN KEY (category_id) REFERENCES ${Tables.categories}(id) ON DELETE RESTRICT
      );
    ''');

    // 6. Task Tags junction table
    batch.execute('''
      CREATE TABLE ${Tables.taskTags} (
        task_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (task_id, tag_id),
        FOREIGN KEY (task_id) REFERENCES ${Tables.tasks}(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES ${Tables.tags}(id) ON DELETE CASCADE
      );
    ''');

    // 7. Task People junction table
    batch.execute('''
      CREATE TABLE ${Tables.taskPeople} (
        task_id TEXT NOT NULL,
        person_id TEXT NOT NULL,
        PRIMARY KEY (task_id, person_id),
        FOREIGN KEY (task_id) REFERENCES ${Tables.tasks}(id) ON DELETE CASCADE,
        FOREIGN KEY (person_id) REFERENCES ${Tables.people}(id) ON DELETE CASCADE
      );
    ''');

    // 8. Sessions table
    batch.execute('''
      CREATE TABLE ${Tables.sessions} (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (task_id) REFERENCES ${Tables.tasks}(id) ON DELETE CASCADE
      );
    ''');

    // 9. Session People junction table
    batch.execute('''
      CREATE TABLE ${Tables.sessionPeople} (
        session_id TEXT NOT NULL,
        person_id TEXT NOT NULL,
        PRIMARY KEY (session_id, person_id),
        FOREIGN KEY (session_id) REFERENCES ${Tables.sessions}(id) ON DELETE CASCADE,
        FOREIGN KEY (person_id) REFERENCES ${Tables.people}(id) ON DELETE CASCADE
      );
    ''');

    // 10. Idle Periods table
    batch.execute('''
      CREATE TABLE ${Tables.idlePeriods} (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        resolution TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES ${Tables.sessions}(id) ON DELETE CASCADE
      );
    ''');

    // 11. Settings table
    batch.execute('''
      CREATE TABLE ${Tables.settings} (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // Performance & Search Indices
    batch.execute('CREATE INDEX idx_tasks_name ON ${Tables.tasks}(name);');
    batch.execute('CREATE INDEX idx_tasks_project_id ON ${Tables.tasks}(project_id);');
    batch.execute('CREATE INDEX idx_tasks_category_id ON ${Tables.tasks}(category_id);');
    batch.execute('CREATE INDEX idx_tasks_last_worked ON ${Tables.tasks}(last_worked_at);');
    batch.execute('CREATE INDEX idx_sessions_task_id ON ${Tables.sessions}(task_id);');
    batch.execute('CREATE INDEX idx_sessions_start_time ON ${Tables.sessions}(start_time);');
    batch.execute('CREATE INDEX idx_sessions_end_time ON ${Tables.sessions}(end_time);');
    batch.execute('CREATE INDEX idx_idle_periods_session_id ON ${Tables.idlePeriods}(session_id);');

    await batch.commit(noResult: true);
  }
}
