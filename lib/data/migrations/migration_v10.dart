import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/data/database/tables.dart';

/// Adds planning fields to `work_items` and creates the `work_item_reminders`
/// ledger table.
class MigrationV10 {
  static Future<void> execute(Database db) async {
    final info = await db.rawQuery('PRAGMA table_info(${Tables.workItems})');
    final columnNames = info.map((col) => col['name'] as String).toSet();

    if (!columnNames.contains('planned_start_date')) {
      await db.execute(
        'ALTER TABLE ${Tables.workItems} ADD COLUMN planned_start_date TEXT;',
      );
    }
    if (!columnNames.contains('due_date')) {
      await db.execute(
        'ALTER TABLE ${Tables.workItems} ADD COLUMN due_date TEXT;',
      );
    }
    if (!columnNames.contains('completed_at')) {
      await db.execute(
        'ALTER TABLE ${Tables.workItems} ADD COLUMN completed_at TEXT;',
      );
    }

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_work_items_due
        ON ${Tables.workItems}(workspace_id, due_date);
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.workItemReminders} (
        id              TEXT PRIMARY KEY,
        work_item_id    TEXT NOT NULL,
        rule            TEXT NOT NULL,
        occurrence_key  TEXT NOT NULL,
        anchor_date     TEXT NOT NULL,
        delivered_at    TEXT NOT NULL,
        read_at         TEXT,
        snoozed_until   TEXT,
        FOREIGN KEY (work_item_id) REFERENCES ${Tables.workItems}(id) ON DELETE CASCADE,
        UNIQUE (work_item_id, rule, occurrence_key)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_work_item_reminders_delivered
        ON ${Tables.workItemReminders}(delivered_at DESC);
    ''');
  }
}
