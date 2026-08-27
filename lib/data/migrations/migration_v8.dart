import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/data/database/tables.dart';

/// Adds discriminator attribute definition support to projects and creates
/// the project_timesheet_codes table for mapping specific options to codes.
///
/// Left null for existing projects: projects without a discriminator
/// continue to book to `projects.timesheet_code` (default code).
class MigrationV8 {
  static Future<void> execute(Database db) async {
    final projectInfo =
        await db.rawQuery('PRAGMA table_info(${Tables.projects})');
    final hasCodeAttributeDefinitionId = projectInfo
        .any((column) => column['name'] == 'code_attribute_definition_id');

    if (!hasCodeAttributeDefinitionId) {
      await db.execute(
        'ALTER TABLE ${Tables.projects} ADD COLUMN code_attribute_definition_id TEXT;',
      );
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.projectTimesheetCodes} (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        attribute_option_id TEXT NOT NULL,
        code TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES ${Tables.projects}(id) ON DELETE CASCADE,
        FOREIGN KEY (attribute_option_id) REFERENCES ${Tables.attributeOptions}(id) ON DELETE CASCADE,
        UNIQUE (project_id, attribute_option_id)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_project_timesheet_codes_project
        ON ${Tables.projectTimesheetCodes}(project_id);
    ''');
  }
}
