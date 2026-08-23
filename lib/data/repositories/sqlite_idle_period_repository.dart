import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/repositories/idle_period_repository.dart';

class SqliteIdlePeriodRepository implements IdlePeriodRepository {
  final DatabaseService _dbService;

  SqliteIdlePeriodRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<List<IdlePeriod>> getIdlePeriodsForSession(String sessionId) async {
    final rows = await _db.query(
      Tables.idlePeriods,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'start_time ASC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<IdlePeriod?> getIdlePeriodById(String id) async {
    final rows = await _db.query(
      Tables.idlePeriods,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<void> createIdlePeriod(IdlePeriod idlePeriod) async {
    await _db.insert(
      Tables.idlePeriods,
      _toMap(idlePeriod),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  @override
  Future<void> updateIdlePeriod(IdlePeriod idlePeriod) async {
    await _db.update(
      Tables.idlePeriods,
      _toMap(idlePeriod),
      where: 'id = ?',
      whereArgs: [idlePeriod.id],
    );
  }

  @override
  Future<void> deleteIdlePeriod(String id) async {
    await _db.delete(
      Tables.idlePeriods,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  IdlePeriod _fromRow(Map<String, Object?> row) {
    return IdlePeriod(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      startTime: DateTime.parse(row['start_time'] as String),
      endTime: DateTime.parse(row['end_time'] as String),
      resolution: IdleResolution.fromString(row['resolution'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Map<String, Object?> _toMap(IdlePeriod idlePeriod) {
    return {
      'id': idlePeriod.id,
      'session_id': idlePeriod.sessionId,
      'start_time': idlePeriod.startTime.toUtc().toIso8601String(),
      'end_time': idlePeriod.endTime.toUtc().toIso8601String(),
      'resolution': idlePeriod.resolution.value,
      'created_at': idlePeriod.createdAt.toUtc().toIso8601String(),
    };
  }
}
