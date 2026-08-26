import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/data/database/tables.dart';

/// Adds the organisation's timesheet code to projects.
///
/// Left null for existing projects rather than backfilled. Unlike the
/// CAPEX/OPEX type in v5 there is no conservative default to reach for: a
/// cost code is an external identifier the app cannot invent, and a made-up
/// one would be booked against real hours. The Time Sheet reports a missing
/// code as missing, and the project form requires one from here on, so the
/// gap closes the first time each project is edited.
class MigrationV6 {
  static Future<void> execute(Database db) async {
    final projectInfo =
        await db.rawQuery('PRAGMA table_info(${Tables.projects})');
    final hasTimesheetCode =
        projectInfo.any((column) => column['name'] == 'timesheet_code');

    if (!hasTimesheetCode) {
      await db.execute(
        'ALTER TABLE ${Tables.projects} ADD COLUMN timesheet_code TEXT;',
      );
    }
  }
}
