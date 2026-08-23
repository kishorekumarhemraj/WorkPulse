import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/repositories/session_repository.dart';

class SqliteSessionRepository implements SessionRepository {
  final DatabaseService _dbService;

  SqliteSessionRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<Session?> getActiveSession() async {
    final rows = await _db.query(
      Tables.sessions,
      where: 'end_time IS NULL',
      orderBy: 'start_time DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final sessions = await _populateSessions(rows);
    return sessions.first;
  }

  @override
  Future<Session?> getSessionById(String id) async {
    final rows = await _db.query(
      Tables.sessions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final sessions = await _populateSessions(rows);
    return sessions.first;
  }

  @override
  Future<List<Session>> getSessionsForTask(String taskId) async {
    final rows = await _db.query(
      Tables.sessions,
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'start_time ASC',
    );
    return _populateSessions(rows);
  }

  @override
  Future<List<Session>> getSessionsInRange(DateTime start, DateTime end) async {
    final rows = await _db.query(
      Tables.sessions,
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [start.toUtc().toIso8601String(), end.toUtc().toIso8601String()],
      orderBy: 'start_time ASC',
    );
    return _populateSessions(rows);
  }

  @override
  Future<List<Session>> getAllSessions() async {
    final rows = await _db.query(
      Tables.sessions,
      orderBy: 'start_time DESC',
    );
    return _populateSessions(rows);
  }

  @override
  Future<void> createSession(Session session) async {
    await _db.transaction((txn) async {
      await txn.insert(
        Tables.sessions,
        _toMap(session),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );

      for (final personId in session.peopleIds) {
        await txn.insert(
          Tables.sessionPeople,
          {'session_id': session.id, 'person_id': personId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  @override
  Future<void> updateSession(Session session) async {
    await _db.transaction((txn) async {
      await txn.update(
        Tables.sessions,
        _toMap(session),
        where: 'id = ?',
        whereArgs: [session.id],
      );

      // Re-sync session people
      await txn.delete(
        Tables.sessionPeople,
        where: 'session_id = ?',
        whereArgs: [session.id],
      );
      for (final personId in session.peopleIds) {
        await txn.insert(
          Tables.sessionPeople,
          {'session_id': session.id, 'person_id': personId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  @override
  Future<void> endSession(String sessionId, DateTime endTime) async {
    await _db.update(
      Tables.sessions,
      {'end_time': endTime.toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<void> deleteSession(String id) async {
    await _db.delete(
      Tables.sessions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Session>> _populateSessions(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return [];

    final sessions = <Session>[];
    for (final row in rows) {
      final sessionId = row['id'] as String;

      final peopleRows = await _db.query(
        Tables.sessionPeople,
        columns: ['person_id'],
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      final peopleIds = peopleRows.map((r) => r['person_id'] as String).toList();

      sessions.add(Session(
        id: sessionId,
        taskId: row['task_id'] as String,
        startTime: DateTime.parse(row['start_time'] as String),
        endTime: row['end_time'] != null ? DateTime.parse(row['end_time'] as String) : null,
        peopleIds: peopleIds,
        createdAt: DateTime.parse(row['created_at'] as String),
      ));
    }
    return sessions;
  }

  Map<String, Object?> _toMap(Session session) {
    return {
      'id': session.id,
      'task_id': session.taskId,
      'start_time': session.startTime.toUtc().toIso8601String(),
      'end_time': session.endTime?.toUtc().toIso8601String(),
      'created_at': session.createdAt.toUtc().toIso8601String(),
    };
  }
}
