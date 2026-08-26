import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/data/database/tables.dart';

/// Adds the CAPEX/OPEX classification to categories.
///
/// Existing categories are backfilled to OPEX. That is a deliberate choice
/// rather than a null-safe one: the Time Sheet reports capitalizable against
/// operational hours, and a third "unknown" bucket for every category created
/// before this release would make the first report unreadable. OPEX is the
/// conservative default — it claims no capitalizable time that the user has
/// not since said is capitalizable.
class MigrationV5 {
  static Future<void> execute(Database db) async {
    final categoryInfo =
        await db.rawQuery('PRAGMA table_info(${Tables.categories})');
    final hasType = categoryInfo.any((column) => column['name'] == 'type');

    if (!hasType) {
      // SQLite permits ADD COLUMN ... NOT NULL only with a constant default,
      // which is exactly the backfill this migration wants.
      await db.execute(
        "ALTER TABLE ${Tables.categories} "
        "ADD COLUMN type TEXT NOT NULL DEFAULT 'OPEX';",
      );
    }

    // Rows that predate the column, or that somehow carry an empty value,
    // are normalised so the reporting layer never has to guess.
    await db.execute(
      "UPDATE ${Tables.categories} "
      "SET type = 'OPEX' WHERE type IS NULL OR TRIM(type) = '';",
    );
  }
}
