import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/data/database/tables.dart';

class MigrationV1 {
  static const String defaultWorkspaceId = 'default-workspace';

  static Future<void> execute(Database db) async {
    final batch = db.batch();

    // 1. Workspaces table
    batch.execute('''
      CREATE TABLE ${Tables.workspaces} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 2. Projects table
    batch.execute('''
      CREATE TABLE ${Tables.projects} (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        color_hex TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        archived_at TEXT,
        FOREIGN KEY (workspace_id) REFERENCES ${Tables.workspaces}(id) ON DELETE CASCADE,
        UNIQUE (workspace_id, name)
      );
    ''');

    // 3. Categories table
    batch.execute('''
      CREATE TABLE ${Tables.categories} (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        icon_name TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        archived_at TEXT,
        FOREIGN KEY (workspace_id) REFERENCES ${Tables.workspaces}(id) ON DELETE CASCADE,
        UNIQUE (workspace_id, name)
      );
    ''');

    // 4. Tags table
    batch.execute('''
      CREATE TABLE ${Tables.tags} (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        name TEXT NOT NULL,
        color_hex TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (workspace_id) REFERENCES ${Tables.workspaces}(id) ON DELETE CASCADE,
        UNIQUE (workspace_id, name)
      );
    ''');

    // 5. People table
    batch.execute('''
      CREATE TABLE ${Tables.people} (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        name TEXT NOT NULL,
        email TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (workspace_id) REFERENCES ${Tables.workspaces}(id) ON DELETE CASCADE,
        UNIQUE (workspace_id, name)
      );
    ''');

    // 6. WorkItems table (replaces tasks, zero Jira in core domain)
    batch.execute('''
      CREATE TABLE ${Tables.workItems} (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        name TEXT NOT NULL,
        project_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_worked_at TEXT,
        archived_at TEXT,
        FOREIGN KEY (workspace_id) REFERENCES ${Tables.workspaces}(id) ON DELETE CASCADE,
        FOREIGN KEY (project_id) REFERENCES ${Tables.projects}(id) ON DELETE RESTRICT,
        FOREIGN KEY (category_id) REFERENCES ${Tables.categories}(id) ON DELETE RESTRICT
      );
    ''');

    // 7. WorkItem Tags junction table
    batch.execute('''
      CREATE TABLE ${Tables.workItemTags} (
        work_item_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (work_item_id, tag_id),
        FOREIGN KEY (work_item_id) REFERENCES ${Tables.workItems}(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES ${Tables.tags}(id) ON DELETE CASCADE
      );
    ''');

    // 8. WorkItem People junction table
    batch.execute('''
      CREATE TABLE ${Tables.workItemPeople} (
        work_item_id TEXT NOT NULL,
        person_id TEXT NOT NULL,
        PRIMARY KEY (work_item_id, person_id),
        FOREIGN KEY (work_item_id) REFERENCES ${Tables.workItems}(id) ON DELETE CASCADE,
        FOREIGN KEY (person_id) REFERENCES ${Tables.people}(id) ON DELETE CASCADE
      );
    ''');

    // 9. Sessions table
    batch.execute('''
      CREATE TABLE ${Tables.sessions} (
        id TEXT PRIMARY KEY,
        work_item_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (work_item_id) REFERENCES ${Tables.workItems}(id) ON DELETE CASCADE
      );
    ''');

    // 10. Session People junction table
    batch.execute('''
      CREATE TABLE ${Tables.sessionPeople} (
        session_id TEXT NOT NULL,
        person_id TEXT NOT NULL,
        PRIMARY KEY (session_id, person_id),
        FOREIGN KEY (session_id) REFERENCES ${Tables.sessions}(id) ON DELETE CASCADE,
        FOREIGN KEY (person_id) REFERENCES ${Tables.people}(id) ON DELETE CASCADE
      );
    ''');

    // 11. Idle Periods table
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

    // 12. Attribute Definitions table (Configurable Attributes)
    batch.execute('''
      CREATE TABLE ${Tables.attributeDefinitions} (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        key TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        type TEXT NOT NULL,
        scope TEXT NOT NULL DEFAULT 'TASK',
        required INTEGER NOT NULL DEFAULT 0,
        enabled INTEGER NOT NULL DEFAULT 1,
        searchable INTEGER NOT NULL DEFAULT 1,
        reportable INTEGER NOT NULL DEFAULT 1,
        show_in_quick_capture INTEGER NOT NULL DEFAULT 1,
        show_in_task_details INTEGER NOT NULL DEFAULT 1,
        display_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        archived_at TEXT,
        FOREIGN KEY (workspace_id) REFERENCES ${Tables.workspaces}(id) ON DELETE CASCADE,
        UNIQUE (workspace_id, key)
      );
    ''');

    // 13. Attribute Options table
    batch.execute('''
      CREATE TABLE ${Tables.attributeOptions} (
        id TEXT PRIMARY KEY,
        attribute_definition_id TEXT NOT NULL,
        value TEXT NOT NULL,
        label TEXT NOT NULL,
        color_hex TEXT,
        display_order INTEGER NOT NULL DEFAULT 0,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        archived_at TEXT,
        FOREIGN KEY (attribute_definition_id) REFERENCES ${Tables.attributeDefinitions}(id) ON DELETE CASCADE
      );
    ''');

    // 14. WorkItem Attribute Values table
    batch.execute('''
      CREATE TABLE ${Tables.workItemAttributeValues} (
        id TEXT PRIMARY KEY,
        work_item_id TEXT NOT NULL,
        attribute_definition_id TEXT NOT NULL,
        text_value TEXT,
        number_value REAL,
        boolean_value INTEGER,
        date_value TEXT,
        option_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (work_item_id) REFERENCES ${Tables.workItems}(id) ON DELETE CASCADE,
        FOREIGN KEY (attribute_definition_id) REFERENCES ${Tables.attributeDefinitions}(id) ON DELETE CASCADE,
        FOREIGN KEY (option_id) REFERENCES ${Tables.attributeOptions}(id) ON DELETE SET NULL
      );
    ''');

    // 15. Session Attribute Values table
    batch.execute('''
      CREATE TABLE ${Tables.sessionAttributeValues} (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        attribute_definition_id TEXT NOT NULL,
        text_value TEXT,
        number_value REAL,
        boolean_value INTEGER,
        date_value TEXT,
        option_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES ${Tables.sessions}(id) ON DELETE CASCADE,
        FOREIGN KEY (attribute_definition_id) REFERENCES ${Tables.attributeDefinitions}(id) ON DELETE CASCADE,
        FOREIGN KEY (option_id) REFERENCES ${Tables.attributeOptions}(id) ON DELETE SET NULL
      );
    ''');

    // 16. Settings table
    batch.execute('''
      CREATE TABLE ${Tables.settings} (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // Performance & Search Indices
    batch.execute('CREATE INDEX idx_work_items_name ON ${Tables.workItems}(name);');
    batch.execute('CREATE INDEX idx_work_items_workspace_id ON ${Tables.workItems}(workspace_id);');
    batch.execute('CREATE INDEX idx_work_items_project_id ON ${Tables.workItems}(project_id);');
    batch.execute('CREATE INDEX idx_work_items_category_id ON ${Tables.workItems}(category_id);');
    batch.execute('CREATE INDEX idx_work_items_last_worked ON ${Tables.workItems}(last_worked_at);');
    batch.execute('CREATE INDEX idx_sessions_work_item_id ON ${Tables.sessions}(work_item_id);');
    batch.execute('CREATE INDEX idx_sessions_start_time ON ${Tables.sessions}(start_time);');
    batch.execute('CREATE INDEX idx_sessions_end_time ON ${Tables.sessions}(end_time);');
    batch.execute('CREATE INDEX idx_idle_periods_session_id ON ${Tables.idlePeriods}(session_id);');
    batch.execute('CREATE INDEX idx_attr_def_workspace_key ON ${Tables.attributeDefinitions}(workspace_id, key);');
    batch.execute('CREATE INDEX idx_attr_opt_def_id ON ${Tables.attributeOptions}(attribute_definition_id);');
    batch.execute('CREATE INDEX idx_wi_attr_val_item ON ${Tables.workItemAttributeValues}(work_item_id);');
    batch.execute('CREATE INDEX idx_sess_attr_val_session ON ${Tables.sessionAttributeValues}(session_id);');

    // Seed default workspace
    final nowIso = DateTime.now().toUtc().toIso8601String();
    batch.insert(Tables.workspaces, {
      'id': defaultWorkspaceId,
      'name': 'Default',
      'created_at': nowIso,
      'updated_at': nowIso,
    });

    await batch.commit(noResult: true);
  }
}
