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
  }
}
