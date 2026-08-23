import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/data/database/tables.dart';

class MigrationV2 {
  static Future<void> execute(Database db) async {
    await db.execute('ALTER TABLE ${Tables.sessions} ADD COLUMN notes TEXT;');
  }
}
