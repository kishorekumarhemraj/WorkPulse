import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/core/extensions/datetime_extensions.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/repositories/session_repository.dart';

class SqliteSessionRepository implements SessionRepository {
  final DatabaseService _dbService;

  SqliteSessionRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<Session?> getById(String id) async {
    final results = await _db.query(
      Tables.sessions,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;

    final sessionMap = results.first;
    final peopleIds = await _getPeopleIds(id);
    return _fromMap(sessionMap, peopleIds);
  }

  @override
  Future<List<Session>> getByWorkItemId(String workItemId) async {
    final results = await _db.query(
      Tables.sessions,
      where: 'work_item_id = ?',
      whereArgs: [workItemId],
      orderBy: 'start_time DESC',
    );

    final sessions = <Session>[];
    for (final map in results) {
      final id = map['id'] as String;
      final peopleIds = await _getPeopleIds(id);
      sessions.add(_fromMap(map, peopleIds));
    }
    return sessions;
  }

  @override
  Future<List<Session>> getByDateRange(DateTime start, DateTime end) async {
    final results = await _db.query(
      Tables.sessions,
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String()
      ],
      orderBy: 'start_time DESC',
    );

    final sessions = <Session>[];
    for (final map in results) {
      final id = map['id'] as String;
      final peopleIds = await _getPeopleIds(id);
      sessions.add(_fromMap(map, peopleIds));
    }
    return sessions;
  }

  @override
  Future<Session?> getActiveSession() async {
    final results = await _db.query(
      Tables.sessions,
      where: 'end_time IS NULL',
      orderBy: 'start_time DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;

    final sessionMap = results.first;
    final id = sessionMap['id'] as String;
    final peopleIds = await _getPeopleIds(id);
    return _fromMap(sessionMap, peopleIds);
  }

  @override
  Future<Session> create(Session session) async {
    try {
      await _db.transaction((txn) async {
        await txn.insert(
          Tables.sessions,
          _toMap(session),
          conflictAlgorithm: ConflictAlgorithm.fail,
        );

        for (final personId in session.peopleIds) {
          await txn.insert(Tables.sessionPeople, {
            'session_id': session.id,
            'person_id': personId,
          });
        }
      });
      return session;
    } catch (e) {
      throw AppDatabaseException('Failed to create session: $e');
    }
  }

  @override
  Future<Session> update(Session session) async {
    try {
      await _db.transaction((txn) async {
        final count = await txn.update(
          Tables.sessions,
          _toMap(session),
          where: 'id = ?',
          whereArgs: [session.id],
        );

        if (count == 0) {
          throw NotFoundException('Session with id ${session.id} not found');
        }

        // Sync people
        await txn.delete(
          Tables.sessionPeople,
          where: 'session_id = ?',
          whereArgs: [session.id],
        );
        for (final personId in session.peopleIds) {
          await txn.insert(Tables.sessionPeople, {
            'session_id': session.id,
            'person_id': personId,
          });
        }
      });
      return session;
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw AppDatabaseException('Failed to update session: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    final count = await _db.delete(
      Tables.sessions,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Session with id $id not found');
    }
  }

  Future<List<String>> _getPeopleIds(String sessionId) async {
    final results = await _db.query(
      Tables.sessionPeople,
      columns: ['person_id'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return results.map((row) => row['person_id'] as String).toList();
  }

  Map<String, dynamic> _toMap(Session session) {
    return {
      'id': session.id,
      'work_item_id': session.workItemId,
      'start_time': session.startTime.toStorageString(),
      'end_time': session.endTime?.toStorageString(),
      'created_at': session.createdAt.toStorageString(),
    };
  }

  Session _fromMap(Map<String, dynamic> map, List<String> peopleIds) {
    return Session(
      id: map['id'] as String,
      workItemId: map['work_item_id'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null
          ? DateTime.parse(map['end_time'] as String)
          : null,
      peopleIds: peopleIds,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
