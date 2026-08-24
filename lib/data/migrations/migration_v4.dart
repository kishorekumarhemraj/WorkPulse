import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/data/database/tables.dart';

class MigrationV4 {
  static Future<void> execute(Database db) async {
    // 1. Create session_tags table if it doesn't already exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.sessionTags} (
        session_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (session_id, tag_id),
        FOREIGN KEY (session_id) REFERENCES ${Tables.sessions}(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES ${Tables.tags}(id) ON DELETE CASCADE
      );
    ''');

    // 2. Backfill historical sessions with category_id from parent work item if null
    await db.execute('''
      UPDATE ${Tables.sessions}
      SET category_id = (
        SELECT ${Tables.workItems}.category_id
        FROM ${Tables.workItems}
        WHERE ${Tables.workItems}.id = ${Tables.sessions}.work_item_id
      )
      WHERE category_id IS NULL;
    ''');

    // 3. Backfill session_tags from parent work_item_tags
    await db.execute('''
      INSERT OR IGNORE INTO ${Tables.sessionTags} (session_id, tag_id)
      SELECT s.id, wit.tag_id
      FROM ${Tables.sessions} s
      JOIN ${Tables.workItemTags} wit ON s.work_item_id = wit.work_item_id;
    ''');

    // 4. Backfill session_people from parent work_item_people
    await db.execute('''
      INSERT OR IGNORE INTO ${Tables.sessionPeople} (session_id, person_id)
      SELECT s.id, wip.person_id
      FROM ${Tables.sessions} s
      JOIN ${Tables.workItemPeople} wip ON s.work_item_id = wip.work_item_id;
    ''');
  }
}
