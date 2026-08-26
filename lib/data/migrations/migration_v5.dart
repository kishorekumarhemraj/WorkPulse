import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/data/database/tables.dart';

/// Puts the financial classification on the task, where it belongs.
///
/// An earlier cut of this migration hung CAPEX/OPEX off the *category*, which
/// forced a false choice: a design meeting about a new feature is capital and
/// the same meeting about last week's outage is not, so "Meetings" could not
/// be one or the other. What decides it is the purpose of the task. So:
///
/// - `work_items.financial_classification` — CAPEX / OPEX / NONE, required.
/// - `sessions.financial_classification` — nullable, meaning "inherit from
///   the task". Set only where one session genuinely differs.
/// - `categories.type` is removed.
///
/// Rewritten in place rather than superseded by a later migration, so the
/// schema carries no vestige of a shape that never shipped. That leaves one
/// hazard: a development database that ran the *old* v5 is already stamped
/// past this version and would never see the rewrite. Every step below is
/// therefore guarded and independently re-runnable, and `DatabaseService`
/// replays this migration on the way to v7 to bring those databases across.
class MigrationV5 {
  static Future<void> execute(Database db) async {
    final workItemColumns = await _columnNames(db, Tables.workItems);
    final sessionColumns = await _columnNames(db, Tables.sessions);
    final categoryColumns = await _columnNames(db, Tables.categories);

    // 1. Tasks carry the classification. NOT NULL with a constant default is
    // the only ADD COLUMN form SQLite accepts for a required column, and
    // NONE is the right default: unclassified is an honest state, whereas
    // defaulting to OPEX would invent a finance decision nobody made.
    if (!workItemColumns.contains('financial_classification')) {
      await db.execute(
        'ALTER TABLE ${Tables.workItems} '
        "ADD COLUMN financial_classification TEXT NOT NULL DEFAULT 'NONE';",
      );
    }

    // 2. Sessions may override it. Nullable on purpose — null is "inherit",
    // and inheritance is resolved on read so correcting a task also corrects
    // the hours it already booked.
    if (!sessionColumns.contains('financial_classification')) {
      await db.execute(
        'ALTER TABLE ${Tables.sessions} '
        'ADD COLUMN financial_classification TEXT;',
      );
    }

    // 3. Carry over what the category-level field already said, for any
    // database that ran the earlier cut. Tasks whose category was CAPEX or
    // OPEX keep that value; everything else stays NONE. Sessions are left to
    // inherit rather than pinned, so a task corrected after the upgrade
    // corrects its history too.
    if (categoryColumns.contains('type')) {
      await db.execute('''
        UPDATE ${Tables.workItems}
        SET financial_classification = (
          SELECT UPPER(c.type)
          FROM ${Tables.categories} c
          WHERE c.id = ${Tables.workItems}.category_id
        )
        WHERE financial_classification = 'NONE'
          AND EXISTS (
            SELECT 1 FROM ${Tables.categories} c
            WHERE c.id = ${Tables.workItems}.category_id
              AND UPPER(c.type) IN ('CAPEX', 'OPEX')
          );
      ''');

      // 4. And drop it. A category names the kind of work; it makes no
      // financial claim any more.
      await db.execute(
        'ALTER TABLE ${Tables.categories} DROP COLUMN type;',
      );
    }

    // 5. Anything unreadable or empty is normalised, so the reporting layer
    // never has to guess what a row meant.
    await db.execute('''
      UPDATE ${Tables.workItems}
      SET financial_classification = 'NONE'
      WHERE financial_classification IS NULL
         OR UPPER(financial_classification) NOT IN ('CAPEX', 'OPEX', 'NONE');
    ''');

    await db.execute('''
      UPDATE ${Tables.sessions}
      SET financial_classification = NULL
      WHERE financial_classification IS NOT NULL
        AND UPPER(financial_classification) NOT IN ('CAPEX', 'OPEX', 'NONE');
    ''');
  }

  static Future<Set<String>> _columnNames(Database db, String table) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    return {for (final column in columns) column['name'] as String};
  }
}
