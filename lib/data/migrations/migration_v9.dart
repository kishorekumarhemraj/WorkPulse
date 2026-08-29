import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/data/database/tables.dart';

/// Gives categories a colour of their own.
///
/// Categories carried an icon but no colour, so every category chip in the
/// app fell back to a neutral fill — and with people and attribute values in
/// the same position, a session row read as five grey chips to one coloured
/// one. Colour is data the user owns, so it belongs in the schema next to
/// `icon_name` rather than being derived at render time the way people's is:
/// a category is a small, deliberate set the user curates, and they should be
/// able to say which one is red.
///
/// **Existing rows are backfilled, not left null.** A nullable column with no
/// backfill means nothing changes until the user hand-edits every category,
/// which is the same complaint arriving again a week later. Rows are assigned
/// from the app's own swatch palette in `created_at` order, so the result is
/// deterministic, matches what the colour picker offers, and is immediately
/// overridable.
class MigrationV9 {
  /// Mirrors `ColorUtils.paletteHex`. Duplicated deliberately: a migration
  /// must keep producing the same values for a database stamped years ago,
  /// which it cannot do if it reads a constant the UI is free to restyle.
  static const List<String> _seedPalette = [
    '#0A84FF',
    '#30D158',
    '#FF9F0A',
    '#BF5AF2',
    '#FF453A',
    '#64D2FF',
    '#FFD60A',
    '#5E5CE6',
    '#FF375F',
    '#8E8E93',
  ];

  static Future<void> execute(Database db) async {
    final info = await db.rawQuery('PRAGMA table_info(${Tables.categories})');
    final hasColorHex = info.any((column) => column['name'] == 'color_hex');

    if (!hasColorHex) {
      await db.execute(
        'ALTER TABLE ${Tables.categories} ADD COLUMN color_hex TEXT;',
      );
    }

    // Guarded so a re-run cannot recolour a category the user has since set.
    final uncoloured = await db.query(
      Tables.categories,
      columns: ['id'],
      where: "color_hex IS NULL OR color_hex = ''",
      orderBy: 'created_at ASC, id ASC',
    );

    for (var i = 0; i < uncoloured.length; i++) {
      await db.update(
        Tables.categories,
        {'color_hex': _seedPalette[i % _seedPalette.length]},
        where: 'id = ?',
        whereArgs: [uncoloured[i]['id']],
      );
    }
  }
}
