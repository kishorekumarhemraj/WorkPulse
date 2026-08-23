import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/repositories/settings_repository.dart';

class SqliteSettingsRepository implements SettingsRepository {
  final DatabaseService _dbService;

  SqliteSettingsRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<String?> getSetting(String key) async {
    final rows = await _db.query(
      Tables.settings,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    await _db.insert(
      Tables.settings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeSetting(String key) async {
    await _db.delete(
      Tables.settings,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  @override
  Future<Map<String, String>> getAllSettings() async {
    final rows = await _db.query(Tables.settings);
    final map = <String, String>{};
    for (final row in rows) {
      map[row['key'] as String] = row['value'] as String;
    }
    return map;
  }
}
