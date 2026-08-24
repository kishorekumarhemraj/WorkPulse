import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/data/database/tables.dart';

class MigrationV3 {
  static Future<void> execute(Database db) async {
    // 1. Add category_id to sessions table
    final sessionInfo =
        await db.rawQuery('PRAGMA table_info(${Tables.sessions})');
    final hasCategoryId =
        sessionInfo.any((column) => column['name'] == 'category_id');
    if (!hasCategoryId) {
      await db
          .execute('ALTER TABLE ${Tables.sessions} ADD COLUMN category_id TEXT;');
    }

    // 2. Add team to people table
    final peopleInfo =
        await db.rawQuery('PRAGMA table_info(${Tables.people})');
    final hasTeam = peopleInfo.any((column) => column['name'] == 'team');
    if (!hasTeam) {
      await db.execute('ALTER TABLE ${Tables.people} ADD COLUMN team TEXT;');
    }
  }
}
